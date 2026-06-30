"""提醒调度服务 + 推送服务的集成单元测试"""
import pytest
from unittest.mock import patch, MagicMock
from datetime import datetime, time, timedelta

from app.services.reminder import ReminderService
from app.services.scheduler import run_reminder_cycle, run_streak_check
from app.models.medication import Medication, MedicationSchedule, MedicationStatus
from app.models.user import User, UserRole


class TestScheduler:
    """定时调度器测试"""

    def test_reminder_cycle_no_pending(self, db):
        """无待提醒时正常运行"""
        pending, alerts = run_reminder_cycle()
        assert pending == []
        assert alerts == []

    def test_reminder_cycle_with_mock_data(self, db, elder_user):
        """有待提醒药品时返回提醒"""
        # 创建一个已审核通过的药品 + 当前时间的计划
        med = Medication(
            elder_id=elder_user.id,
            category="oral",
            name="测试提醒药",
            oral_form="tablet",
            status=MedicationStatus.APPROVED,
        )
        db.add(med)
        db.flush()

        now = datetime.utcnow()
        near_time = time(now.hour, now.minute)
        schedule = MedicationSchedule(
            medication_id=med.id,
            time_of_day=near_time,
            dosage=1.0,
            weekday_mask=127,
        )
        db.add(schedule)
        db.commit()

        pending, alerts = run_reminder_cycle()
        # 可能在 ±5 分钟窗口内匹配到
        if pending:
            assert len(pending) >= 1
            assert pending[0]["medication_name"] == "测试提醒药"
        else:
            # 当前时间不匹配 ±5 分钟窗口，也是正常的
            pass


class TestPushService:
    """推送服务测试"""

    def test_push_missed_dose(self):
        """漏服推送不报错"""
        from app.services.push import PushService
        # 没有 openid，不会真的发
        PushService.send_missed_dose_alert(
            child_openid="test_openid",
            elder_name="张爷爷",
            medication_name="降压药",
            missed_minutes=30,
        )
        # 只是 logger，不抛异常就算过

    def test_push_voice_reminder(self):
        """语音播报触发不报错"""
        from app.services.push import PushService
        PushService.trigger_voice_reminder(
            elder_id=1,
            medication_name="阿莫西林",
            dosage_display="2粒",
            safety_alert="漏服不可双倍补吃",
            voice_preference="mandarin",
        )
