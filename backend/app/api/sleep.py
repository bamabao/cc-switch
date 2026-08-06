"""爸妈宝 — 睡眠监测 API
设备上报 + 手动录入 + 查询（7天趋势/最近记录）
"""
import json
import logging
from datetime import datetime, date, timedelta
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from app.models.base import SessionLocal
from app.models.sleep_record import SleepRecord, sleep_score_label

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/sleep", tags=["sleep"])


class SleepUpsert(BaseModel):
    elder_id: int
    sleep_date: str                      # YYYY-MM-DD（入睡日期）
    sleep_score: int = 0
    total_minutes: int = 0
    deep_minutes: int = 0
    light_minutes: int = 0
    rem_minutes: int = 0
    awake_minutes: int = 0
    efficiency: float = 0
    bedtime: str = ""
    wake_time: str = ""
    latency_minutes: int = 0
    avg_hr: float = 0
    lowest_hr: float = 0
    avg_hrv: float = 0
    avg_spo2: float = 0
    breathing_disturbances: int = 0
    source: str = "manual"
    device_id: str = ""
    device_model: str = ""


@router.post("/upsert")
def upsert_sleep(req: SleepUpsert):
    """上报/更新睡眠记录（设备或手动，按日期去重）"""
    db = SessionLocal()
    try:
        d = date.fromisoformat(req.sleep_date)
        rec = db.query(SleepRecord).filter(
            SleepRecord.elder_id == req.elder_id,
            SleepRecord.sleep_date == d,
        ).first()
        if rec is None:
            rec = SleepRecord(elder_id=req.elder_id, sleep_date=d)
            db.add(rec)

        # 更新字段
        rec.sleep_score = req.sleep_score
        rec.total_minutes = req.total_minutes
        rec.deep_minutes = req.deep_minutes
        rec.light_minutes = req.light_minutes
        rec.rem_minutes = req.rem_minutes
        rec.awake_minutes = req.awake_minutes
        rec.efficiency = req.efficiency
        rec.bedtime = req.bedtime
        rec.wake_time = req.wake_time
        rec.latency_minutes = req.latency_minutes
        rec.avg_hr = req.avg_hr
        rec.lowest_hr = req.lowest_hr
        rec.avg_hrv = req.avg_hrv
        rec.avg_spo2 = req.avg_spo2
        rec.breathing_disturbances = req.breathing_disturbances
        rec.source = req.source
        rec.device_id = req.device_id
        rec.device_model = req.device_model

        db.commit()
        db.refresh(rec)
        return {"success": True, "id": rec.id, "sleep_date": rec.sleep_date.isoformat()}
    finally:
        db.close()


@router.get("/history/{elder_id}")
def get_sleep_history(elder_id: int, days: int = 7, token: str = ""):
    """睡眠历史（倒序，最近days天）
    安全：token存在则校验，无token仅demo用户1
    """
    if token:
        from app.core.security import require_elder_id
        auth = require_elder_id(token)
        if auth != elder_id:
            raise HTTPException(403, "无权访问其他用户数据")
    elif elder_id != 1:
        raise HTTPException(403, "请先登录")

    db = SessionLocal()
    try:
        since = date.today() - timedelta(days=days)
        recs = db.query(SleepRecord).filter(
            SleepRecord.elder_id == elder_id,
            SleepRecord.sleep_date >= since,
        ).order_by(SleepRecord.sleep_date.desc()).all()
        return {"history": [r.to_dict() for r in recs]}
    finally:
        db.close()


@router.get("/latest/{elder_id}")
def get_latest_sleep(elder_id: int):
    """最近一晚睡眠详情"""
    db = SessionLocal()
    try:
        rec = db.query(SleepRecord).filter(
            SleepRecord.elder_id == elder_id,
        ).order_by(SleepRecord.sleep_date.desc()).first()
        if not rec:
            return {"latest": None}
        d = rec.to_dict()
        d["score_label"] = sleep_score_label(rec.sleep_score)
        return {"latest": d}
    finally:
        db.close()


@router.get("/week-summary/{elder_id}")
def get_week_summary(elder_id: int):
    """近7天睡眠汇总：平均评分/平均时长/最佳夜晚"""
    db = SessionLocal()
    try:
        since = date.today() - timedelta(days=7)
        recs = db.query(SleepRecord).filter(
            SleepRecord.elder_id == elder_id,
            SleepRecord.sleep_date >= since,
        ).all()
        if not recs:
            return {"count": 0, "avg_score": None, "avg_minutes": None, "best": None}
        avg_score = sum(r.sleep_score for r in recs) // len(recs)
        avg_minutes = sum(r.total_minutes for r in recs) // len(recs)
        best = max(recs, key=lambda r: r.sleep_score)
        return {
            "count": len(recs),
            "avg_score": avg_score,
            "avg_minutes": avg_minutes,
            "best_date": best.sleep_date.isoformat(),
            "best_score": best.sleep_score,
        }
    finally:
        db.close()
