"""爸妈宝 — 健康指标 API
- 穿戴设备数据接入（手表/指环/血糖仪/血压计，预留统一协议）
- 手动录入
- 查询（曲线图数据）
"""
import json
import logging
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from app.models.base import SessionLocal
from app.models.health_metric import HealthMetric, MetricType, DeviceSource, METRIC_CONFIG

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/health", tags=["health"])


# ─── 协议模型 ───

class MetricCreate(BaseModel):
    metric_type: str                       # blood_pressure / blood_glucose / ...
    value: float
    value2: Optional[float] = None
    unit: Optional[str] = ""
    measured_at: Optional[str] = None      # ISO时间，缺省用当前
    context: Optional[str] = ""            # 空腹/餐后/睡前/晨起
    note: Optional[str] = ""


class DeviceMetricBatch(BaseModel):
    """穿戴设备批量上报（一次最多50条）"""
    device_id: str = Field(..., min_length=1, max_length=64)
    device_model: str = ""
    elder_id: int
    metrics: list[MetricCreate]


# ─── 设备鉴权（简易设备密钥，正式版换OAuth/加密） ───
DEVICE_TOKENS = {
    "bamaobao-watch-demo": "demo",   # 爸妈宝手表（预留）
    "oura-ring-demo": "demo",        # Oura Ring 类设备（预留）
    "glucose-meter-demo": "demo",    # 血糖仪（预留）
    "bp-monitor-demo": "demo",       # 血压计（预留）
}


def _check_device_auth(device_id: str):
    # 正式版：验证设备签名/密钥
    if device_id not in DEVICE_TOKENS:
        return False
    return True


def _parse_type(t: str) -> MetricType:
    for mt in MetricType:
        if mt.value == t or mt.name.lower() == t:
            return mt
    raise HTTPException(400, f"不支持的指标类型: {t}")


# ─── API ───

@router.post("/device/batch")
def device_batch_upload(req: DeviceMetricBatch):
    """穿戴设备批量上报健康数据（手表/戒指/血糖仪）"""
    if not _check_device_auth(req.device_id):
        raise HTTPException(403, "设备未授权")

    db = SessionLocal()
    try:
        saved = 0
        for m in req.metrics[:50]:
            try:
                mt = _parse_type(m.metric_type)
            except HTTPException:
                continue
            measured = datetime.fromisoformat(m.measured_at) if m.measured_at else datetime.utcnow()
            rec = HealthMetric(
                elder_id=req.elder_id,
                metric_type=mt,
                value=m.value,
                value2=m.value2,
                unit=m.unit or METRIC_CONFIG.get(mt, {}).get("unit", ""),
                measured_at=measured,
                context=m.context,
                note=m.note,
                source=DeviceSource.WEARABLE,
                device_id=req.device_id,
                device_model=req.device_model,
            )
            db.add(rec)
            saved += 1
        db.commit()
        return {"success": True, "saved": saved, "message": f"已接收设备上报{saved}条数据"}
    finally:
        db.close()


class ManualMetricCreate(BaseModel):
    elder_id: int
    metric_type: str
    value: float
    value2: Optional[float] = None
    unit: Optional[str] = ""
    measured_at: Optional[str] = None
    context: Optional[str] = ""
    note: Optional[str] = ""


@router.post("/manual")
def manual_create(req: ManualMetricCreate):
    """手动录入健康指标（血压/血糖/尿酸等）"""
    db = SessionLocal()
    try:
        mt = _parse_type(req.metric_type)
        measured = datetime.fromisoformat(req.measured_at) if req.measured_at else datetime.utcnow()
        rec = HealthMetric(
            elder_id=req.elder_id,
            metric_type=mt,
            value=req.value,
            value2=req.value2,
            unit=req.unit or METRIC_CONFIG.get(mt, {}).get("unit", ""),
            measured_at=measured,
            context=req.context,
            note=req.note,
            source=DeviceSource.MANUAL,
        )
        db.add(rec)
        db.commit()
        db.refresh(rec)
        return {"success": True, "id": rec.id}
    finally:
        db.close()


@router.get("/history/{elder_id}/{metric_type}")
def get_history(elder_id: int, metric_type: str, days: int = 30, limit: int = 200, token: str = ""):
    """查询健康指标历史（曲线图数据，按时间升序）
    安全：elder_id 必须与 token 中的 user_id 匹配，防越权
    """
    # 越权防护：token存在则必须匹配，无token（demo模式）仅限 elder_id=1
    if token:
        from app.core.security import require_elder_id
        auth_elder = require_elder_id(token)
        if auth_elder != elder_id:
            raise HTTPException(403, "无权访问其他用户数据")
    elif elder_id != 1:
        raise HTTPException(403, "请先登录")

    db = SessionLocal()
    try:
        mt = _parse_type(metric_type)
        since = datetime.utcnow() - timedelta(days=days)
        recs = db.query(HealthMetric).filter(
            HealthMetric.elder_id == elder_id,
            HealthMetric.metric_type == mt,
            HealthMetric.measured_at >= since,
        ).order_by(HealthMetric.measured_at.asc()).limit(limit).all()
        return {"metric_type": mt.value, "config": METRIC_CONFIG.get(mt, {}),
                "data": [r.to_dict() for r in recs]}
    finally:
        db.close()


@router.get("/latest/{elder_id}")
def get_latest(elder_id: int):
    """最新各项指标（首页/看板用）"""
    db = SessionLocal()
    try:
        result = {}
        for mt in MetricType:
            rec = db.query(HealthMetric).filter(
                HealthMetric.elder_id == elder_id,
                HealthMetric.metric_type == mt,
            ).order_by(HealthMetric.measured_at.desc()).first()
            if rec:
                result[mt.value] = rec.to_dict()
        return {"elder_id": elder_id, "latest": result}
    finally:
        db.close()


@router.get("/summary/{elder_id}/{metric_type}")
def get_summary(elder_id: int, metric_type: str, days: int = 7):
    """指标汇总：平均值/最高/最低/测量次数"""
    from sqlalchemy import func
    db = SessionLocal()
    try:
        mt = _parse_type(metric_type)
        since = datetime.utcnow() - timedelta(days=days)
        rows = db.query(HealthMetric).filter(
            HealthMetric.elder_id == elder_id,
            HealthMetric.metric_type == mt,
            HealthMetric.measured_at >= since,
        ).all()
        if not rows:
            return {"metric_type": mt.value, "count": 0, "avg": None, "max": None, "min": None}
        values = [r.value for r in rows]
        return {
            "metric_type": mt.value,
            "count": len(rows),
            "avg": round(sum(values) / len(values), 1),
            "max": max(values),
            "min": min(values),
            "unit": rows[0].unit,
        }
    finally:
        db.close()
