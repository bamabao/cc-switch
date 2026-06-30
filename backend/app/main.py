"""
爸妈宝 — FastAPI 主入口

启动:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
"""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.models.base import engine, Base
from app.api import medication as medication_api
from app.api import audit as audit_api
from app.api import points as points_api
from app.api import auth as auth_api
from app.services.scheduler import run_reminder_cycle
import threading

logger = logging.getLogger("bamabao.main")

# 建表
Base.metadata.create_all(bind=engine)


_scheduler_thread = None


def _start_periodic_check():
    """后台线程：每 5 分钟执行一次提醒检测"""
    import time
    while True:
        time.sleep(300)  # 5 分钟
        try:
            run_reminder_cycle()
        except Exception as e:
            logger.warning(f"定时提醒检测失败: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    logger.info("爸妈宝 API 启动完成")
    
    # 启动时执行一轮提醒检测
    try:
        pending, alerts = run_reminder_cycle()
        if pending or alerts:
            logger.info(f"启动检测: {len(pending)} 条提醒, {len(alerts)} 条告警")
    except Exception as e:
        logger.warning(f"启动提醒检测失败（非致命）: {e}")
    
    # 启动后台提醒线程
    global _scheduler_thread
    _scheduler_thread = threading.Thread(target=_start_periodic_check, daemon=True)
    _scheduler_thread.start()
    logger.info("后台提醒线程已启动（每5分钟检测）")
    
    yield
    
    logger.info("爸妈宝 API 关闭")


app = FastAPI(
    title="爸妈宝 API",
    description="老人端 APP + 子女端微信小程序 — 药品全生命周期管理",
    version="0.2.0",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(medication_api.router)
app.include_router(audit_api.router)
app.include_router(points_api.router)
app.include_router(auth_api.router)


@app.get("/api/v1/health")
def health_check():
    return {"status": "ok", "app": "爸妈宝", "version": "0.2.0"}
