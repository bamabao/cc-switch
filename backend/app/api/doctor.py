"""爸妈宝医生版 — 医生注册/认证/套餐 API"""
import json
import logging
import uuid
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from app.models.base import SessionLocal
from app.models.doctor import Doctor, DoctorStatus, SubscriptionPlan, Order, DoctorPatient, AuditLog
from app.services.ai_service import _call_deepseek

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/doctor", tags=["doctor"])


# ─── 套餐价格表 ───
PLANS = {
    "free":     {"price": 0,   "patients": 10,  "assistants": 0, "name": "免费版"},
    "personal": {"price": 29,  "patients": 50,  "assistants": 1, "name": "个人版"},
    "studio":   {"price": 99,  "patients": 200, "assistants": 2, "name": "工作室版"},
    "hospital": {"price": 299, "patients": 9999, "assistants": 10, "name": "医院版"},
}


class DoctorRegister(BaseModel):
    phone: str = Field(..., min_length=11, max_length=11)
    real_name: str = Field(..., min_length=2, max_length=64)
    hospital: str = Field(..., min_length=2, max_length=128)
    department: str = Field(..., min_length=1, max_length=64)
    title: str = Field(..., min_length=1, max_length=32)
    license_no: str = Field(..., min_length=5, max_length=64)
    practice_no: str = Field(..., min_length=5, max_length=64)
    id_card: str = Field(..., min_length=15, max_length=18)
    email: str = Field("", max_length=128)
    license_photo: str = ""
    practice_photo: str = ""
    idcard_photo: str = ""


class AssistantRegister(BaseModel):
    phone: str = Field(..., min_length=11, max_length=11)
    real_name: str = Field(..., min_length=2, max_length=64)
    license_no: str = Field(..., min_length=5, max_length=64)
    id_card: str = Field(..., min_length=15, max_length=18)


class BindPatient(BaseModel):
    doctor_id: int
    patient_phone: str


class SubscribePlan(BaseModel):
    doctor_id: int
    plan: str
    months: int = Field(1, ge=1, le=24)


def _get_doctor(db, doctor_id: int) -> Doctor:
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    if not doctor:
        raise HTTPException(404, "医生不存在")
    return doctor


# ─── 医生注册 ───

@router.post("/register")
def register_doctor(req: DoctorRegister):
    """医生实名注册（需上传资质，人工审核）"""
    db = SessionLocal()
    try:
        # 手机号查重
        if db.query(Doctor).filter(Doctor.phone == req.phone).first():
            raise HTTPException(400, "该手机号已注册")

        doctor = Doctor(
            phone=req.phone,
            real_name=req.real_name,
            hospital=req.hospital,
            department=req.department,
            title=req.title,
            license_no=req.license_no,
            practice_no=req.practice_no,
            id_card=req.id_card,
            email=req.email,
            license_photo=req.license_photo,
            practice_photo=req.practice_photo,
            idcard_photo=req.idcard_photo,
            status=DoctorStatus.PENDING,
            plan=SubscriptionPlan.FREE,
            patient_quota=PLANS["free"]["patients"],
        )
        db.add(doctor)
        db.commit()
        db.refresh(doctor)
        return {"doctor_id": doctor.id, "status": "pending", "message": "注册成功，资质审核中（1-2个工作日）"}
    finally:
        db.close()


# ─── 助理医生注册（自己实名注册，主任再授权） ───

@router.post("/register-assistant")
def register_assistant(req: AssistantRegister):
    """助理医生实名注册"""
    db = SessionLocal()
    try:
        if db.query(Doctor).filter(Doctor.phone == req.phone).first():
            raise HTTPException(400, "该手机号已注册")
        doctor = Doctor(
            phone=req.phone,
            real_name=req.real_name,
            license_no=req.license_no,
            id_card=req.id_card,
            status=DoctorStatus.PENDING,
            plan=SubscriptionPlan.FREE,
        )
        db.add(doctor)
        db.commit()
        db.refresh(doctor)
        return {"doctor_id": doctor.id, "status": "pending", "message": "助理医生注册成功，审核中"}
    finally:
        db.close()


# ─── 医患绑定 ───

@router.post("/bind-patient")
def bind_patient(req: BindPatient):
    """医生绑定患者（需患者同意）"""
    from app.models.doctor import DoctorPatient
    from app.models.user import User

    db = SessionLocal()
    try:
        doctor = _get_doctor(db, req.doctor_id)
        if doctor.status != DoctorStatus.APPROVED:
            raise HTTPException(403, "医生账号未通过审核")

        patient = db.query(User).filter(User.phone == req.patient_phone).first()
        if not patient:
            raise HTTPException(404, "患者未注册爸妈宝")

        # 检查名额
        existing = db.query(DoctorPatient).filter(
            DoctorPatient.doctor_id == req.doctor_id,
            DoctorPatient.is_active == True
        ).count()
        if existing >= doctor.patient_quota:
            raise HTTPException(400, f"患者名额已满（{doctor.patient_quota}人），请升级套餐")

        # 查重
        if db.query(DoctorPatient).filter(
            DoctorPatient.doctor_id == req.doctor_id,
            DoctorPatient.patient_id == patient.id,
            DoctorPatient.is_active == True
        ).first():
            raise HTTPException(400, "该患者已绑定")

        binding = DoctorPatient(
            doctor_id=req.doctor_id,
            patient_id=patient.id,
            auth_expire_at=datetime.utcnow() + timedelta(days=180),
        )
        db.add(binding)
        db.add(AuditLog(actor_type="doctor", actor_id=req.doctor_id, action="bind_patient",
                        target_type="patient", target_id=patient.id))
        db.commit()
        return {"success": True, "message": "绑定成功", "binding_id": binding.id}
    finally:
        db.close()


# ─── 套餐订阅 ───

@router.post("/subscribe")
def subscribe(req: SubscribePlan):
    """订阅套餐（生成订单）"""
    db = SessionLocal()
    try:
        doctor = _get_doctor(db, req.doctor_id)
        plan_key = req.plan.lower()
        if plan_key not in PLANS:
            raise HTTPException(400, "套餐不存在")

        plan_info = PLANS[plan_key]
        amount = plan_info["price"] * req.months

        order = Order(
            order_no=f"BM{datetime.now().strftime('%Y%m%d%H%M%S')}{uuid.uuid4().hex[:6]}",
            doctor_id=req.doctor_id,
            plan=SubscriptionPlan(plan_key),
            amount=amount,
            months=req.months,
        )
        db.add(order)
        db.commit()
        db.refresh(order)
        return {"order_no": order.order_no, "amount": amount, "plan": plan_key, "plan_name": plan_info["name"]}
    finally:
        db.close()


@router.post("/subscribe/confirm")
def confirm_subscribe(order_no: str, pay_method: str = "wechat"):
    """模拟支付成功（正式环境接入微信/支付宝支付）"""
    db = SessionLocal()
    try:
        order = db.query(Order).filter(Order.order_no == order_no).first()
        if not order:
            raise HTTPException(404, "订单不存在")
        if order.status == "paid":
            return {"success": True, "message": "已支付"}

        order.status = "paid"
        order.pay_method = pay_method
        order.paid_at = datetime.utcnow()

        doctor = db.query(Doctor).filter(Doctor.id == order.doctor_id).first()
        plan_info = PLANS[order.plan.value]
        doctor.plan = order.plan
        doctor.patient_quota = plan_info["patients"]
        doctor.assistant_quota = plan_info["assistants"]
        doctor.plan_expire_at = datetime.utcnow() + timedelta(days=30 * order.months)

        db.add(AuditLog(actor_type="doctor", actor_id=order.doctor_id, action="subscribe",
                        target_type="order", target_id=order.id, detail=f"{order.plan.value} {order.months}个月 ¥{order.amount}"))
        db.commit()
        return {"success": True, "message": f"订阅成功，有效期至 {doctor.plan_expire_at.strftime('%Y-%m-%d')}"}
    finally:
        db.close()


# ─── 医生信息 ───

@router.get("/{doctor_id}")
def get_doctor(doctor_id: int):
    """获取医生信息"""
    db = SessionLocal()
    try:
        doctor = _get_doctor(db, doctor_id)
        return {
            "id": doctor.id,
            "real_name": doctor.real_name,
            "hospital": doctor.hospital,
            "department": doctor.department,
            "title": doctor.title,
            "status": doctor.status.value,
            "plan": doctor.plan.value,
            "patient_quota": doctor.patient_quota,
            "assistant_quota": doctor.assistant_quota,
            "plan_expire_at": doctor.plan_expire_at.isoformat() if doctor.plan_expire_at else None,
        }
    finally:
        db.close()


# ─── AI 医生资质预审核（辅助人工） ───

@router.post("/audit/{doctor_id}/approve")
def approve_doctor(doctor_id: int):
    """人工审核通过（管理后台调用）"""
    db = SessionLocal()
    try:
        doctor = _get_doctor(db, doctor_id)
        if doctor.status == DoctorStatus.APPROVED:
            return {"success": True, "message": "已通过"}
        doctor.status = DoctorStatus.APPROVED
        db.add(AuditLog(actor_type="admin", actor_id=0, action="approve_doctor",
                        target_type="doctor", target_id=doctor_id))
        db.commit()
        return {"success": True, "message": f"{doctor.real_name} 审核通过"}
    finally:
        db.close()


@router.post("/audit/{doctor_id}/reject")
def reject_doctor(doctor_id: int, reason: str = ""):
    """人工审核拒绝"""
    db = SessionLocal()
    try:
        doctor = _get_doctor(db, doctor_id)
        doctor.status = DoctorStatus.REJECTED
        db.add(AuditLog(actor_type="admin", actor_id=0, action="reject_doctor",
                        target_type="doctor", target_id=doctor_id, detail=reason))
        db.commit()
        return {"success": True, "message": f"已拒绝：{reason}"}
    finally:
        db.close()


@router.post("/audit/ai-preview")
def ai_audit_preview(real_name: str, hospital: str, title: str, department: str):
    """AI辅助审核 - 检查信息合理性（人工仍为最终决定）"""
    result = _call_deepseek([
        {"role": "system", "content": "你是医院资质审核助手。判断医生信息是否合理。输出JSON：{reasonable: bool, concerns: [问题列表]}。只输出JSON。"},
        {"role": "user", "content": f"姓名:{real_name} 医院:{hospital} 职称:{title} 科室:{department}"},
    ], temperature=0.1, max_tokens=200)
    try:
        return json.loads(result)
    except Exception:
        return {"reasonable": True, "concerns": ["AI分析不可用，需人工审核"]}
