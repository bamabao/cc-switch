"""爸妈宝 安全防护层 — 越权防护 + 速率限制
- 关键API强制校验JWT token
- elder_id 以token内user_id为准，忽略客户端传入（防越权）
- 简单内存速率限制（防刷接口）
"""
import time
import threading
from datetime import datetime
from fastapi import HTTPException, Request
from jose import jwt, JWTError

from app.core.config import get_settings

settings = get_settings()

# ─── 内存速率限制 ───
_rate_limit_store = {}
_rate_lock = threading.Lock()
RATE_LIMIT_PER_IP = 300          # 每IP每分钟最多300次
RATE_WINDOW = 60


def check_rate_limit(request: Request):
    """简单速率限制：每IP每分钟N次"""
    client_ip = request.client.host if request.client else "unknown"
    now = time.time()
    with _rate_lock:
        window_start = now - RATE_WINDOW
        # 清理过期
        for k in list(_rate_limit_store.keys()):
            if _rate_limit_store[k][0] < window_start:
                del _rate_limit_store[k]
        count, first = _rate_limit_store.get(client_ip, (0, now))
        if count >= RATE_LIMIT_PER_IP:
            raise HTTPException(429, "请求过于频繁，请稍后再试")
        _rate_limit_store[client_ip] = (count + 1, first)


def verify_token(token: str) -> dict:
    """校验JWT token，返回payload"""
    if not token:
        raise HTTPException(401, "未登录或token缺失")
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        return payload
    except JWTError:
        raise HTTPException(401, "token无效或已过期")


def require_elder_id(token: str) -> int:
    """从token解析用户ID（防越权：忽略客户端传的elder_id）"""
    payload = verify_token(token)
    user_id = payload.get("user_id") or payload.get("sub")
    if user_id is None:
        raise HTTPException(401, "token中无用户ID")
    return int(user_id)


def require_doctor_id(token: str) -> int:
    """从token解析医生ID"""
    payload = verify_token(token)
    doctor_id = payload.get("doctor_id") or payload.get("sub")
    if doctor_id is None:
        raise HTTPException(401, "token中无医生ID")
    return int(doctor_id)


def audit_log(actor_type: str, actor_id: int, action: str, target: str = "", detail: str = ""):
    """写审计日志（等保要求）"""
    try:
        from app.models.base import SessionLocal
        from app.models.doctor import AuditLog
        db = SessionLocal()
        db.add(AuditLog(
            actor_type=actor_type, actor_id=actor_id,
            action=action, target_type="api", target_id=0,
            detail=f"{target} {detail}"[:500],
        ))
        db.commit()
        db.close()
    except Exception:
        pass
