"""
用药提醒服务
- 到期超大弹窗 + 方言/普通话语音播报
- 超时15分钟二次提醒
- 超时30分钟未确认，推送告警给子女
- 安全语音警示
"""
from datetime import datetime, timedelta, time
from typing import List, Optional
from sqlalchemy.orm import Session

from app.models.base import SessionLocal
from app.models.medication import (
    Medication, MedicationSchedule, MedicationLog,
    MedicationStatus
)
from app.models.user import User, FamilyBinding
from app.models.point import PointTransaction, TransactionType


class ReminderService:
    """提醒调度服务（供定时任务调用）"""

    def __init__(self, db: Session):
        self.db = db

    def check_pending_doses(self) -> List[dict]:
        """
        检查当前待提醒的用药计划。
        返回需要弹窗/播报的提醒列表。
        """
        now = datetime.utcnow()
        current_time = now.time()
        results = []

        # 查找所有已审核通过且今天有定时计划的药品
        schedules = (
            self.db.query(MedicationSchedule)
            .join(Medication)
            .filter(
                Medication.status == MedicationStatus.APPROVED,
                MedicationSchedule.is_active == True,
            )
            .all()
        )

        for schedule in schedules:
            med = schedule.medication
            # 当前时间与计划时间相差 ±5 分钟内
            plan = schedule.time_of_day
            if abs(self._time_diff_minutes(current_time, plan)) > 5:
                continue

            # 检查是否已经确认
            existing = (
                self.db.query(MedicationLog)
                .filter(
                    MedicationLog.schedule_id == schedule.id,
                    MedicationLog.scheduled_time >= now - timedelta(minutes=10),
                )
                .first()
            )
            if existing and existing.confirmed_time:
                continue

            # 需要提醒
            alert_info = self._get_safety_alert(med.category)
            results.append({
                "elder_id": med.elder_id,
                "medication_id": med.id,
                "medication_name": med.name,
                "dosage": schedule.dosage,
                "dosage_display": schedule.dosage_display,
                "category": med.category.value,
                "safety_alert": alert_info,
                "reminder_type": "initial" if not existing else "secondary",
                "schedule_id": schedule.id,
            })

            # 记录提醒发送
            if not existing:
                log = MedicationLog(
                    medication_id=med.id,
                    elder_id=med.elder_id,
                    schedule_id=schedule.id,
                    scheduled_time=datetime.combine(now.date(), schedule.time_of_day),
                    reminder_sent_1=now,
                    status="missed",  # 初始为漏服，确认后更新
                )
                self.db.add(log)
            else:
                existing.reminder_sent_2 = now

            self.db.commit()

        return results

    def check_missed_doses(self) -> List[dict]:
        """检查超时30分钟未确认的用药，触发子女告警"""
        now = datetime.utcnow()
        threshold = now - timedelta(minutes=30)
        alerts = []

        missed_logs = (
            self.db.query(MedicationLog)
            .filter(
                MedicationLog.confirmed_time.is_(None),
                MedicationLog.reminder_sent_1.isnot(None),
                MedicationLog.alert_sent_to_child == False,
                MedicationLog.scheduled_time <= threshold,
            )
            .all()
        )

        for log in missed_logs:
            med = log.medication
            # 查找绑定的子女
            bindings = (
                self.db.query(FamilyBinding)
                .filter(
                    FamilyBinding.elder_id == med.elder_id,
                    FamilyBinding.is_active == True,
                )
                .all()
            )

            log.alert_sent_to_child = True
            child_ids = [b.child_id for b in bindings]

            alerts.append({
                "elder_id": med.elder_id,
                "child_ids": child_ids,
                "medication_name": med.name,
                "missed_minutes": int((now - log.scheduled_time).total_seconds() / 60),
                "scheduled_time": log.scheduled_time.isoformat(),
            })

        self.db.commit()
        return alerts

    def grant_reward(self, elder_id: int, medication_log_id: int) -> int:
        """用药确认后发放积分奖励"""
        user = self.db.query(User).filter(User.id == elder_id).first()
        if not user:
            return 0

        points = 10  # 单次完成用药
        user.total_points += points

        tx = PointTransaction(
            elder_id=elder_id,
            type=TransactionType.REWARD_DOSE,
            amount=points,
            balance_after=user.total_points,
            description="按时用药奖励",
            reference_id=str(medication_log_id),
        )
        self.db.add(tx)
        self.db.commit()
        return points

    def grant_streak_bonus(self, elder_id: int, streak_days: int) -> Optional[int]:
        """连续打卡额外奖励"""
        user = self.db.query(User).filter(User.id == elder_id).first()
        if not user:
            return None

        bonus = 0
        if streak_days == 7:
            bonus = 50
        elif streak_days == 30:
            bonus = 200
        elif streak_days > 0 and streak_days % 30 == 0:
            bonus = 200  # 每30天循环奖励

        if bonus > 0:
            user.total_points += bonus
            tx_type = TransactionType.REWARD_STREAK_30 if streak_days >= 30 else TransactionType.REWARD_STREAK_7
            tx = PointTransaction(
                elder_id=elder_id,
                type=tx_type,
                amount=bonus,
                balance_after=user.total_points,
                description=f"连续{streak_days}天打卡奖励",
            )
            self.db.add(tx)
            self.db.commit()

        return bonus

    # ========== 内部工具 ==========

    @staticmethod
    def _time_diff_minutes(t1: time, t2: time) -> float:
        """计算两个时间的分钟差"""
        dt1 = timedelta(hours=t1.hour, minutes=t1.minute)
        dt2 = timedelta(hours=t2.hour, minutes=t2.minute)
        return (dt1 - dt2).total_seconds() / 60.0

    @staticmethod
    def _get_safety_alert(category) -> str:
        """根据药品分类返回安全语音警示"""
        alerts = {
            "oral": "请注意：漏服不可双倍补吃，请按时按量服用",
            "external": "请注意：外用药切勿口服，请在患处涂抹使用",
            "injection": "请注意：针剂禁止过量注射，请严格按照医嘱使用",
            "supplement": "请注意：请按推荐剂量服用保健药品",
        }
        return alerts.get(category, "请按照医嘱用药")
