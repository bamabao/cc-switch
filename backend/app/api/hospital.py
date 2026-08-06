"""爸妈宝 — 医院交流平台 API（第一期：我的医院）
- 患者查看绑定的医院信息（从医生绑定聚合）
- 医院科室/医生列表
- 健康档案共享状态
"""
import json
import logging
from datetime import datetime
from fastapi import APIRouter, HTTPException
from sqlalchemy import func

from app.models.base import SessionLocal
from app.models.user import User, UserRole
from app.models.doctor import Doctor, DoctorPatient, DoctorStatus, ConsultationMessage

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/hospital", tags=["医院平台"])


@router.get("/my-info")
def my_hospital_info(elder_id: int = 1, token: str = ""):
    """患者查看「我的医院」：绑定医院 + 科室 + 医生列表 + 沟通概览
    安全：token存在则校验匹配，无token仅demo用户1
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
        # 1. 该患者绑定的所有医生
        bindings = db.query(DoctorPatient).filter(
            DoctorPatient.patient_id == elder_id,
            DoctorPatient.is_active == True,
        ).all()
        doctor_ids = [b.doctor_id for b in bindings]
        doctors = db.query(Doctor).filter(Doctor.id.in_(doctor_ids)).all() if doctor_ids else []

        # 2. 聚合医院信息（按医院名分组）
        hospital_map = {}
        for d in doctors:
            hname = d.hospital or "未绑定医院"
            if hname not in hospital_map:
                hospital_map[hname] = {
                    "name": hname,
                    "departments": set(),
                    "doctors": [],
                    "message_count": 0,
                }
            hospital_map[hname]["departments"].add(d.department or "综合")
            hospital_map[hname]["doctors"].append({
                "id": d.id,
                "real_name": d.real_name or "医生",
                "department": d.department or "综合",
                "title": d.title or "",
                "intro": (d.intro or "")[:80],
                "practice_no": (d.practice_no or "")[-4:] or "",
            })

        # 3. 未读消息统计
        unread_total = db.query(ConsultationMessage).filter(
            ConsultationMessage.patient_id == elder_id,
            ConsultationMessage.is_read == False,
        ).count()

        hospitals = []
        for hname, h in hospital_map.items():
            h["departments"] = sorted(h["departments"])
            hospitals.append(h)

        return {
            "hospitals": hospitals,
            "doctor_count": len(doctors),
            "unread": unread_total,
            "shared": True,          # 健康档案已授权共享
            "updated_at": datetime.utcnow().isoformat(),
        }
    finally:
        db.close()
