"""
爸妈宝 — 消息推送服务（一期模板）

对接微信小程序订阅消息 + 语音播报触发。
一期先做接口定义，二期对接真实推送通道。

支持的事件类型：
  1. 漏服告警 → 推送子女微信
  2. 待审核提醒 → 推送子女微信
  3. 用药确认 → 触发语音播报
  4. 连续打卡成功 → 推送老人/子女
  5. 过期/余量预警 → 推送子女
"""
import logging
from typing import Optional, List

logger = logging.getLogger("bamabao.push")


class PushService:
    """消息推送服务"""

    # ========== 子女小程序订阅消息 ==========

    @staticmethod
    def send_missed_dose_alert(
        child_openid: str,
        elder_name: str,
        medication_name: str,
        missed_minutes: int,
    ):
        """
        漏服告警 → 子女微信
        模板: 老人 {{elder_name}} 的药品 {{medication_name}} 
              已超时 {{missed_minutes}} 分钟未确认服药
        """
        # TODO: 调微信订阅消息 API
        # POST https://api.weixin.qq.com/cgi-bin/message/subscribe/send
        # {
        #   "touser": child_openid,
        #   "template_id": "漏服模板ID",
        #   "data": {
        #     "thing1": {"value": elder_name},
        #     "thing2": {"value": medication_name},
        #     "time3": {"value": f"{missed_minutes}分钟前"}
        #   }
        # }
        logger.info(
            f"[推送-漏服告警] 子女{child_openid} | "
            f"老人{elder_name} | 药品{medication_name} | "
            f"超时{missed_minutes}分钟"
        )

    @staticmethod
    def send_pending_review_alert(
        child_openid: str,
        elder_name: str,
        medication_name: str,
    ):
        """
        新药品待审核 → 子女微信
        """
        logger.info(
            f"[推送-待审核] 子女{child_openid} | "
            f"老人{elder_name} | 药品{medication_name} 待审核"
        )

    @staticmethod
    def send_expiry_warning(
        child_openid: str,
        elder_name: str,
        medication_name: str,
        days_remaining: int,
    ):
        """
        药品过期预警 → 子女微信
        """
        logger.info(
            f"[推送-过期预警] 子女{child_openid} | "
            f"老人{elder_name} | 药品{medication_name} | "
            f"剩余{days_remaining}天"
        )

    # ========== 老人端语音播报 ==========

    @staticmethod
    def trigger_voice_reminder(
        elder_id: int,
        medication_name: str,
        dosage_display: str,
        safety_alert: str = "",
        voice_preference: str = "mandarin",
    ):
        """
        触发老人端语音播报
        voice_preference: mandarin | cantonese | sichuan | ...
        """
        # TODO: 对接科大讯飞 TTS / 阿里云 TTS
        # 生成播报文本 → 下发语音文件URL到老人APP
        text = f"请服用 {medication_name}，{dosage_display}。{safety_alert}"
        logger.info(
            f"[播报] 老人{elder_id} | "
            f"方言: {voice_preference} | "
            f"内容: {text}"
        )

    # ========== 批量推送 ==========

    @staticmethod
    def batch_notify_children(
        child_ids: List[int],
        elder_name: str,
        medication_name: str,
        notify_type: str,
        extra: Optional[dict] = None,
    ):
        """
        向所有绑定子女批量推送通知
        """
        # 从数据库查询子女的 openid
        from app.models.base import SessionLocal
        from app.models.user import User

        db = SessionLocal()
        try:
            children = (
                db.query(User)
                .filter(User.id.in_(child_ids), User.role == "child")
                .all()
            )
            for child in children:
                if not child.openid:
                    logger.warning(f"子女{child.id} 无 openid，跳过推送")
                    continue

                if notify_type == "missed_dose":
                    PushService.send_missed_dose_alert(
                        child.openid,
                        elder_name,
                        medication_name,
                        extra.get("missed_minutes", 0) if extra else 0,
                    )
                elif notify_type == "pending_review":
                    PushService.send_pending_review_alert(
                        child.openid, elder_name, medication_name
                    )
                elif notify_type == "expiry_warning":
                    PushService.send_expiry_warning(
                        child.openid,
                        elder_name,
                        medication_name,
                        extra.get("days_remaining", 0) if extra else 0,
                    )
        finally:
            db.close()
