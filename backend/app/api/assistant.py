"""爸妈宝医生版 — 助理医生授权管理 API"""
import json
import logging
from datetime import datetime
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from app.models.base import SessionLocal
from app.models.doctor import Doctor, DoctorAssistant, DoctorStatus, AuditLog

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/assistant", tags=["assistant"])


class InviteAssistant(BaseModel):
    doctor_id: int           # 主治医生
    assistant_phone: str     # 助理手机号
    can_reply: bool = True
    can_view_data: bool = True
    need_approval: bool = True
    patient_ids: list[int] = []
    role: str = "assistant_doctor"


class RevokeAssistant(BaseModel):
    doctor_id: int
    assistant_id: int


class UpdateAssistant(BaseModel):
    doctor_id: int
    assistant_id: int
    can_reply: Optional[bool] = None
    can_view_data: Optional[bool] = None
    need_approval: Optional[bool] = None
    patient_ids: Optional[list[int]] = None


def _get_approved_doctor(db, doctor_id: int) -> Doctor:
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    if not doctor:
        raise HTTPException(404, "医生不存在")
    if doctor.status != DoctorStatus.APPROVED:
        raise HTTPException(403, "医生账号未通过审核")
    return doctor


@router.post("/invite")
def invite_assistant(req: InviteAssistant):
    """主治医生授权助理（助理必须先自己实名注册）"""
    db = SessionLocal()
    try:
        doctor = _get_approved_doctor(db, req.doctor_id)

        # 检查助理名额
        existing = db.query(DoctorAssistant).filter(
            DoctorAssistant.doctor_id == req.doctor_id,
            DoctorAssistant.is_active == True
        ).count()
        if existing >= doctor.assistant_quota:
            raise HTTPException(400, f"助理名额已用完（{doctor.assistant_quota}名），请升级套餐")

        # 查找助理
        assistant = db.query(Doctor).filter(Doctor.phone == req.assistant_phone).first()
        if not assistant:
            raise HTTPException(404, "该手机号未注册医生版，请先注册")
        if assistant.id == req.doctor_id:
            raise HTTPException(400, "不能把自己设为助理")
        if assistant.status != DoctorStatus.APPROVED:
            raise HTTPException(400, "助理账号未通过审核")

        # 查重
        if db.query(DoctorAssistant).filter(
            DoctorAssistant.doctor_id == req.doctor_id,
            DoctorAssistant.assistant_id == assistant.id,
            DoctorAssistant.is_active == True
        ).first():
            raise HTTPException(400, "该助理已授权")

        binding = DoctorAssistant(
            doctor_id=req.doctor_id,
            assistant_id=assistant.id,
            can_reply=req.can_reply,
            can_view_data=req.can_view_data,
            need_approval=req.need_approval,
            patient_ids=json.dumps(req.patient_ids),
            role=req.role,
        )
        db.add(binding)
        db.add(AuditLog(actor_type="doctor", actor_id=req.doctor_id, action="invite_assistant",
                        target_type="doctor", target_id=assistant.id))
        db.commit()
        db.refresh(binding)
        return {"success": True, "message": f"已授权助理：{assistant.real_name}", "binding_id": binding.id}
    finally:
        db.close()


@router.post("/revoke")
def revoke_assistant(req: RevokeAssistant):
    """主治医生撤销助理授权"""
    db = SessionLocal()
    try:
        binding = db.query(DoctorAssistant).filter(
            DoctorAssistant.doctor_id == req.doctor_id,
            DoctorAssistant.assistant_id == req.assistant_id,
            DoctorAssistant.is_active == True
        ).first()
        if not binding:
            raise HTTPException(404, "授权关系不存在")

        binding.is_active = False
        binding.revoked_at = datetime.utcnow()
        db.add(AuditLog(actor_type="doctor", actor_id=req.doctor_id, action="revoke_assistant",
                        target_type="doctor", target_id=req.assistant_id))
        db.commit()
        return {"success": True, "message": "已撤销助理授权，权限立即失效"}
    finally:
        db.close()


@router.post("/update")
def update_assistant(req: UpdateAssistant):
    """修改助理权限"""
    db = SessionLocal()
    try:
        binding = db.query(DoctorAssistant).filter(
            DoctorAssistant.doctor_id == req.doctor_id,
            DoctorAssistant.assistant_id == req.assistant_id,
            DoctorAssistant.is_active == True
        ).first()
        if not binding:
            raise HTTPException(404, "授权关系不存在")

        if req.can_reply is not None:
            binding.can_reply = req.can_reply
        if req.can_view_data is not None:
            binding.can_view_data = req.can_view_data
        if req.need_approval is not None:
            binding.need_approval = req.need_approval
        if req.patient_ids is not None:
            binding.patient_ids = json.dumps(req.patient_ids)

        db.commit()
        return {"success": True, "message": "权限已更新"}
    finally:
        db.close()


@router.get("/list/{doctor_id}")
def list_assistants(doctor_id: int):
    """查看主治医生的助理列表"""
    db = SessionLocal()
    try:
        bindings = db.query(DoctorAssistant).filter(
            DoctorAssistant.doctor_id == doctor_id,
            DoctorAssistant.is_active == True
        ).all()
        result = []
        for b in bindings:
            assistant = db.query(Doctor).filter(Doctor.id == b.assistant_id).first()
            result.append({
                "assistant_id": b.assistant_id,
                "name": assistant.real_name if assistant else "未知",
                "role": b.role,
                "can_reply": b.can_reply,
                "can_view_data": b.can_view_data,
                "need_approval": b.need_approval,
                "patient_ids": json.loads(b.patient_ids or "[]"),
                "created_at": b.created_at.isoformat(),
            })
        return {"assistants": result, "quota": db.query(Doctor).filter(Doctor.id == doctor_id).first().assistant_quota}
    finally:
        db.close()


@router.get("/my/{assistant_id}")
def my_bindings(assistant_id: int):
    """助理查看自己被哪些医生授权"""
    db = SessionLocal()
    try:
        bindings = db.query(DoctorAssistant).filter(
            DoctorAssistant.assistant_id == assistant_id,
            DoctorAssistant.is_active == True
        ).all()
        result = []
        for b in bindings:
            doctor = db.query(Doctor).filter(Doctor.id == b.doctor_id).first()
            result.append({
                "doctor_id": b.doctor_id,
                "doctor_name": doctor.real_name if doctor else "未知",
                "hospital": doctor.hospital if doctor else "",
                "can_reply": b.can_reply,
                "can_view_data": b.can_view_data,
                "need_approval": b.need_approval,
            })
        return {"bindings": result}
    finally:
        db.close()
