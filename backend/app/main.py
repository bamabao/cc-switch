"""
爸妈宝 - FastAPI 主入口

启动:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
"""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware

from app.models.base import engine, Base
from app.api import medication as medication_api
from app.api import points as points_api
from app.api import auth as auth_api
from app.api import emergency_contact as emergency_contact_api
from app.api import ocr as ocr_api
from app.api import drug_instruction as drug_api
from app.api import app_version as app_api
from app.api import ai as ai_api
from app.api import doctor as doctor_api
from app.api import chat as chat_api
from app.api import assistant as assistant_api
from app.api import admin as admin_api
from app.api import prescription as prescription_api
from app.api import health as health_api
from app.api import sleep as sleep_api
from app.api import erp as erp_api
from app.api import hospital as hospital_api
from app.services.scheduler import run_reminder_cycle, run_streak_check
import threading

logger = logging.getLogger("bamabao.main")

# 建表
Base.metadata.create_all(bind=engine)


_scheduler_thread = None


def _start_background_tasks():
    """后台线程：每 5 分钟执行提醒检测 + 每小时检查连续打卡"""
    import time
    last_streak_check_day = None
    while True:
        time.sleep(300)  # 5 分钟
        try:
            run_reminder_cycle()
        except Exception as e:
            logger.warning(f"定时提醒检测失败: {e}")

        # 每天凌晨 00:10-01:00 之间执行一次连续打卡检查
        now = time.localtime()
        current_day = now.tm_mday
        if now.tm_hour == 0 and now.tm_min >= 10 and last_streak_check_day != current_day:
            try:
                run_streak_check()
                last_streak_check_day = current_day
                logger.info("连续打卡检查完成")
            except Exception as e:
                logger.warning(f"连续打卡检查失败: {e}")


def _start_periodic_check():
    """后台线程:每 5 分钟执行一次提醒检测"""
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
        logger.warning(f"启动提醒检测失败(非致命): {e}")

    # 启动后台提醒线程
    global _scheduler_thread
    _scheduler_thread = threading.Thread(target=_start_background_tasks, daemon=True)
    _scheduler_thread.start()
    logger.info("后台线程已启动（提醒每5分钟 / 连续打卡每日凌晨）")

    yield
    
    logger.info("爸妈宝 API 关闭")


app = FastAPI(
    title="爸妈宝 API",
    description="老人端 APP + 子女端微信小程序 - 药品全生命周期管理",
    version="0.2.0",
    lifespan=lifespan,
)

# 中间件：确保所有 JSON 响应带 charset=utf-8，防止 Flutter http 包默认 latin1 解码破坏中文
@app.middleware("http")
async def ensure_json_charset(request: Request, call_next):
    response: Response = await call_next(request)
    ct = response.headers.get("content-type", "")
    if ct.startswith("application/json") and "charset" not in ct:
        response.headers["content-type"] = "application/json; charset=utf-8"
    return response


# 安全中间件：API 速率限制（防刷接口）
@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    path = request.url.path
    # 仅对API限流，静态文件/健康检查不限制
    if path.startswith("/api/v1/") and not path.endswith("/health"):
        try:
            from app.core.security import check_rate_limit
            check_rate_limit(request)
        except HTTPException as e:
            return Response(content=f'{{"detail":"{e.detail}"}}', status_code=e.status_code,
                            media_type="application/json; charset=utf-8")
    return await call_next(request)


# 安全中间件：Token 从 Header 读取（Authorization: Bearer <token>）
# 防止 token 出现在 URL/日志中；同时兼容旧版 URL query 传参
@app.middleware("http")
async def token_from_header(request: Request, call_next):
    path = request.url.path
    if path.startswith("/api/v1/"):
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth[7:].strip()
            if token:
                # 若 query 中无 token，则注入
                query = request.url.query
                if "token=" not in query:
                    sep = "&" if query else ""
                    query += f"{sep}token={token}"
                    # 重写 scope 的 query_string 与 query_params
                    from urllib.parse import parse_qsl
                    request.scope["query_string"] = query.encode()
                    request.scope["query_params"] = _QueryParams(query)
    return await call_next(request)


class _QueryParams:
    """轻量 query params 包装（满足 FastAPI 依赖需要）"""
    def __init__(self, query: str):
        from urllib.parse import parse_qsl
        self._dict = dict(parse_qsl(query, keep_blank_values=True))
        self._list = [(k, v) for k, v in parse_qsl(query, keep_blank_values=True)]

    def get(self, key, default=None):
        return self._dict.get(key, default)

    def __getitem__(self, key):
        return self._dict[key]

    def __contains__(self, key):
        return key in self._dict

    def items(self):
        return self._dict.items()

    def keys(self):
        return self._dict.keys()

    def multi_items(self):
        return self._list

    def __len__(self):
        return len(self._dict)


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
app.include_router(points_api.router)
app.include_router(auth_api.router)
app.include_router(emergency_contact_api.router)
app.include_router(ocr_api.router)
app.include_router(drug_api.router)
app.include_router(app_api.router)
app.include_router(ai_api.router)
app.include_router(doctor_api.router)
app.include_router(chat_api.router)
app.include_router(assistant_api.router)
app.include_router(admin_api.router)
app.include_router(prescription_api.router)
app.include_router(health_api.router)
app.include_router(sleep_api.router)
app.include_router(erp_api.router)
app.include_router(hospital_api.router)


@app.get("/api/v1/health")
def health_check():
    return {"status": "ok", "app": "爸妈宝", "version": "0.2.0"}
