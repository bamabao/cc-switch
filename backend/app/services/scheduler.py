"""
爸妈宝 — 定时调度器

驱动 ReminderService 的定时任务，生产环境使用 APScheduler。
开发环境可通过 uvicorn 启动时注册后台任务。

用法：
    # 方式一：随 uvicorn 启动（推荐开发环境）
    uvicorn app.main:app --reload
    # 会自动在 app 启动时注册调度器

    # 方式二：独立运行（推荐生产环境）
    python -m app.scheduler
"""
import logging

from app.models.base import SessionLocal
from app.services.reminder import ReminderService

logger = logging.getLogger("bamabao.scheduler")


def run_reminder_cycle():
    """执行一轮提醒检测"""
    db = SessionLocal()
    try:
        service = ReminderService(db)

        # 1. 检查待提醒的用药计划
        pending = service.check_pending_doses()
        for p in pending:
            logger.info(
                f"[提醒] 老人{p['elder_id']} | "
                f"药品: {p['medication_name']} | "
                f"剂量: {p.get('dosage_display', p['dosage'])} | "
                f"类型: {p['reminder_type']}"
            )
            # TODO: 对接推送服务，实际发送语音弹窗/播报

        # 2. 检查超时未确认，触发子女告警
        alerts = service.check_missed_doses()
        for a in alerts:
            logger.warning(
                f"[告警] 老人{a['elder_id']} 漏服 | "
                f"药品: {a['medication_name']} | "
                f"已超时: {a['missed_minutes']}分钟 | "
                f"子女IDs: {a['child_ids']}"
            )
            # TODO: 对接推送服务，发送微信订阅消息

        if pending or alerts:
            logger.info(
                f"本轮: {len(pending)} 条提醒, {len(alerts)} 条告警"
            )
        return pending, alerts
    finally:
        db.close()


def run_streak_check():
    """每日检查连续打卡奖励（凌晨执行）"""
    db = SessionLocal()
    try:
        service = ReminderService(db)
        from app.models.user import User
        # 查找昨日有用药记录但还没领连续奖励的老人
        users = db.query(User).filter(
            User.role == "elder",
            User.current_streak > 0,
        ).all()
        for user in users:
            if user.current_streak in (7, 30) or (
                user.current_streak > 30 and user.current_streak % 30 == 0
            ):
                bonus = service.grant_streak_bonus(user.id, user.current_streak)
                if bonus:
                    logger.info(
                        f"[连续打卡奖励] 老人{user.id} | "
                        f"连续{user.current_streak}天 | "
                        f"奖励{bonus}积分"
                    )
    finally:
        db.close()


# ============================================================
# APScheduler 集成（生产环境推荐）
# ============================================================
# 安装：pip install apscheduler
# 
# from apscheduler.schedulers.background import BackgroundScheduler
# 
# scheduler = BackgroundScheduler()
# 
# def start_scheduler():
#     # 提醒检测：每 2 分钟运行一次
#     scheduler.add_job(
#         run_reminder_cycle,
#         'interval',
#         minutes=2,
#         id='reminder_check',
#         max_instances=1,
#     )
#     # 连续打卡检查：每天 00:10
#     scheduler.add_job(
#         run_streak_check,
#         'cron',
#         hour=0,
#         minute=10,
#         id='streak_check',
#     )
#     scheduler.start()
#     logger.info("调度器已启动：提醒每2分钟 | 连续打卡每日00:10")
# 
# def stop_scheduler():
#     scheduler.shutdown()

# ============================================================
# 独立运行入口
# ============================================================
if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    )
    logger.info("爸妈宝调度器 - 手动运行模式")
    
    pending, alerts = run_reminder_cycle()
    print(f"提醒: {len(pending)} 条, 告警: {len(alerts)} 条")
