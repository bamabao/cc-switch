"""爸妈宝医生版 — 电子处方/用药方案 API"""
import json
import logging
import uuid
from datetime import datetime
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from app.models.base import SessionLocal
from app.models.doctor import Prescription, PrescriptionItem, Doctor, DoctorStatus, AuditLog
from app.models.user import User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/prescription", tags=["prescription"])


class PrescItem(BaseModel):
    drug_name: str = Field(..., min_length=1, max_length=128)
    category: str = "oral"
    dosage_per_take: float = 1
    unit: str = "粒"
    frequency_per_day: int = 3
    times: list[str] = ["08:00", "12:00", "18:00"]
    meal_relation: str = ""
    duration_days: int = 7
    notes: str = ""
    total_quantity: float = 0


class CreatePrescription(BaseModel):
    doctor_id: int
    patient_id: int
    title: str = ""
    summary: str = ""
    disease_group: str = ""
    items: list[PrescItem]


@router.post("/create")
def create_prescription(req: CreatePrescription):
    """医生创建用药方案并发送给患者"""
    db = SessionLocal()
    try:
        doctor = db.query(Doctor).filter(Doctor.id == req.doctor_id).first()
        if not doctor or doctor.status != DoctorStatus.APPROVED:
            raise HTTPException(403, "医生账号未通过审核")

        patient = db.query(User).filter(User.id == req.patient_id).first()
        if not patient:
            raise HTTPException(404, "患者不存在")

        # 校验绑定关系
        from app.models.doctor import DoctorPatient
        binding = db.query(DoctorPatient).filter(
            DoctorPatient.doctor_id == req.doctor_id,
            DoctorPatient.patient_id == req.patient_id,
            DoctorPatient.is_active == True
        ).first()
        if not binding:
            raise HTTPException(403, "医患未绑定，无法发送方案")

        if not req.items:
            raise HTTPException(400, "方案至少包含一种药")

        items_json = json.dumps([item.model_dump() for item in req.items], ensure_ascii=False)

        presc = Prescription(
            presc_no=f"RX{datetime.now().strftime('%Y%m%d%H%M%S')}{uuid.uuid4().hex[:6].upper()}",
            doctor_id=req.doctor_id,
            patient_id=req.patient_id,
            title=req.title or f"{doctor.real_name}的用药方案",
            summary=req.summary,
            disease_group=req.disease_group,
            items_json=items_json,
            status="pending",
        )
        db.add(presc)
        db.add(AuditLog(actor_type="doctor", actor_id=req.doctor_id, action="send_prescription",
                        target_type="patient", target_id=req.patient_id,
                        detail=f"{len(req.items)}种药"))
        db.commit()
        db.refresh(presc)
        return {"prescription_id": presc.id, "presc_no": presc.presc_no,
                "status": "pending", "message": "用药方案已发送给患者"}
    finally:
        db.close()


@router.get("/pending/{patient_id}")
def pending_prescriptions(patient_id: int, token: str = ""):
    """患者查看待接收的用药方案
    安全：token存在则校验，无token仅demo用户1
    """
    if token:
        from app.core.security import require_elder_id
        auth = require_elder_id(token)
        if auth != patient_id:
            raise HTTPException(403, "无权访问其他用户数据")
    elif patient_id != 1:
        raise HTTPException(403, "请先登录")

    db = SessionLocal()
    try:
        prescs = db.query(Prescription).filter(
            Prescription.patient_id == patient_id,
            Prescription.status == "pending"
        ).order_by(Prescription.created_at.desc()).all()

        result = []
        for p in prescs:
            doctor = db.query(Doctor).filter(Doctor.id == p.doctor_id).first()
            result.append({
                "id": p.id,
                "presc_no": p.presc_no,
                "title": p.title,
                "summary": p.summary,
                "disease_group": p.disease_group,
                "doctor_name": doctor.real_name if doctor else "医生",
                "doctor_hospital": doctor.hospital if doctor else "",
                "doctor_title": doctor.title if doctor else "",
                "items": json.loads(p.items_json),
                "created_at": p.created_at.isoformat(),
            })
        return {"prescriptions": result}
    finally:
        db.close()


@router.get("/history/{patient_id}")
def prescription_history(patient_id: int, limit: int = 20):
    """患者历史方案（已接收/已拒绝）"""
    db = SessionLocal()
    try:
        prescs = db.query(Prescription).filter(
            Prescription.patient_id == patient_id,
            Prescription.status != "pending"
        ).order_by(Prescription.created_at.desc()).limit(limit).all()

        result = []
        for p in prescs:
            doctor = db.query(Doctor).filter(Doctor.id == p.doctor_id).first()
            result.append({
                "id": p.id,
                "title": p.title,
                "status": p.status,
                "doctor_name": doctor.real_name if doctor else "医生",
                "items": json.loads(p.items_json),
                "created_at": p.created_at.isoformat(),
                "received_at": p.received_at.isoformat() if p.received_at else None,
            })
        return {"prescriptions": result}
    finally:
        db.close()


@router.post("/accept/{prescription_id}")
def accept_prescription(prescription_id: int):
    """患者一键接收方案 → 自动创建药品+提醒"""
    from app.models.medication import Medication, MedicationSchedule, DrugCategory, OralForm, MedicationStatus
    import json as _json

    db = SessionLocal()
    try:
        presc = db.query(Prescription).filter(Prescription.id == prescription_id).first()
        if not presc:
            raise HTTPException(404, "方案不存在")
        if presc.status != "pending":
            raise HTTPException(400, "该方案已处理")

        items = _json.loads(presc.items_json)
        created_meds = []

        for item in items:
            # 检查是否已存在同名药品
            existing = db.query(Medication).filter(
                Medication.elder_id == presc.patient_id,
                Medication.name == item["drug_name"]
            ).first()

            if existing:
                # 已有该药则更新
                existing.dosage_per_take = item.get("dosage_per_take", 1)
                existing.unit = item.get("unit", "粒")
                existing.frequency_per_day = item.get("frequency_per_day", 3)
                existing.meal_relation = item.get("meal_relation", "")
                existing.total_quantity = item.get("total_quantity", 0)
                existing.status = MedicationStatus.APPROVED
                med = existing
                # 清除旧时间表重新创建
                db.query(MedicationSchedule).filter(
                    MedicationSchedule.medication_id == med.id
                ).delete()
            else:
                med = Medication(
                    elder_id=presc.patient_id,
                    name=item["drug_name"],
                    category=DrugCategory(item.get("category", "oral")) if item.get("category") in [e.value for e in DrugCategory] else DrugCategory.ORAL,
                    oral_form=OralForm.TABLET,
                    dosage_per_take=item.get("dosage_per_take", 1),
                    unit=item.get("unit", "粒"),
                    frequency_per_day=item.get("frequency_per_day", 3),
                    meal_relation=item.get("meal_relation", ""),
                    total_quantity=item.get("total_quantity", 0),
                    notes=item.get("notes", ""),
                    status=MedicationStatus.APPROVED,
                )
                db.add(med)
                db.flush()

            # 创建服药时间表
            times = item.get("times", ["08:00", "12:00", "18:00"])
            for t in times:
                hour, minute = t.split(":")
                schedule = MedicationSchedule(
                    medication_id=med.id,
                    time_of_day=datetime.utcnow().replace(hour=int(hour), minute=int(minute), second=0, microsecond=0).time(),
                    dosage=item.get("dosage_per_take", 1),
                    is_active=True,
                )
                db.add(schedule)

            created_meds.append({"name": item["drug_name"], "id": med.id})

        presc.status = "accepted"
        presc.received_at = datetime.utcnow()
        db.add(AuditLog(actor_type="patient", actor_id=presc.patient_id, action="accept_prescription",
                        target_type="prescription", target_id=presc.id,
                        detail=f"{len(created_meds)}种药"))
        db.commit()
        return {"success": True, "message": f"已接收方案，创建{len(created_meds)}种药品提醒",
                "medications": created_meds}
    finally:
        db.close()


@router.post("/reject/{prescription_id}")
def reject_prescription(prescription_id: int, reason: str = ""):
    """患者拒绝方案"""
    db = SessionLocal()
    try:
        presc = db.query(Prescription).filter(Prescription.id == prescription_id).first()
        if not presc:
            raise HTTPException(404, "方案不存在")
        if presc.status != "pending":
            raise HTTPException(400, "该方案已处理")

        presc.status = "rejected"
        presc.summary = (presc.summary or "") + f"\n[患者拒绝：{reason}]"
        db.commit()
        return {"success": True, "message": "已拒绝该方案，医生会收到通知"}
    finally:
        db.close()
