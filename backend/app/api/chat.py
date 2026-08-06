"""爸妈宝医生版 — 医患聊天 + AI建议回复 API"""
import json
import logging
from datetime import datetime
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from app.models.base import SessionLocal
from app.models.doctor import Doctor, DoctorPatient, ConsultationMessage, DoctorAssistant, AuditLog
from app.models.user import User
from app.services.ai_service import _call_deepseek, check_emergency

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/chat", tags=["chat"])


class SendMessage(BaseModel):
    doctor_id: int
    patient_id: int
    sender_role: str = Field("patient", pattern="^(patient|doctor|assistant)$")
    sender_id: int
    content: str = Field(..., min_length=1, max_length=2000)
    msg_type: str = Field("text", pattern="^(text|image|audio|approval)$")


def _check_binding(db, doctor_id: int, patient_id: int) -> bool:
    """校验医患绑定关系"""
    return db.query(DoctorPatient).filter(
        DoctorPatient.doctor_id == doctor_id,
        DoctorPatient.patient_id == patient_id,
        DoctorPatient.is_active == True
    ).first() is not None


@router.post("/send")
def send_message(req: SendMessage):
    """发送消息（患者→医生 / 医生→患者 / 助理→患者）"""
    db = SessionLocal()
    try:
        if not _check_binding(db, req.doctor_id, req.patient_id):
            raise HTTPException(403, "医患未绑定")

        is_emergency = check_emergency(req.content)

        # AI建议回复（仅医生/助理发消息时不生成，患者消息才生成）
        ai_suggestions = []
        if req.sender_role == "patient":
            ai_suggestions = _generate_ai_suggestions(db, req.content, req.patient_id, req.doctor_id)

        msg = ConsultationMessage(
            doctor_id=req.doctor_id,
            patient_id=req.patient_id,
            sender_role=req.sender_role,
            sender_id=req.sender_id,
            msg_type=req.msg_type,
            content=req.content,
            is_emergency=is_emergency,
            ai_suggestions=json.dumps(ai_suggestions, ensure_ascii=False),
        )
        db.add(msg)
        db.add(AuditLog(actor_type=req.sender_role, actor_id=req.sender_id, action="send_msg",
                        target_type="patient", target_id=req.patient_id))
        db.commit()
        db.refresh(msg)
        return {"id": msg.id, "is_emergency": is_emergency, "ai_suggestions": ai_suggestions}
    finally:
        db.close()


def _generate_ai_suggestions(db, patient_msg: str, patient_id: int, doctor_id: int) -> list:
    """AI生成3条建议回复，供医生/助理快速选择"""
    # 获取患者用药信息作为上下文
    from app.models.medication import Medication
    meds = db.query(Medication).filter(Medication.elder_id == patient_id).all()
    med_names = "、".join([m.name for m in meds[:5]]) if meds else "无"

    prompt = f"""患者留言：{patient_msg}
患者当前用药：{med_names}

请生成3条医生回复建议，要求：
1. 每条≤50字，语气专业温和
2. 第一条：通用安抚+建议观察
3. 第二条：具体用药建议（如涉及）
4. 第三条：建议就医/复诊
5. 输出JSON数组格式：["建议1","建议2","建议3"]
6. 如果患者描述紧急症状，第一条必须以⚠️开头并建议立即就医
只输出JSON数组。"""

    try:
        result = _call_deepseek([
            {"role": "system", "content": "你是医生助理，生成简洁的回复建议。"},
            {"role": "user", "content": prompt},
        ], temperature=0.5, max_tokens=400)
        # 解析JSON数组
        result = result.strip()
        if result.startswith("```"):
            result = result.split("\n", 1)[1].rsplit("```", 1)[0].strip()
        suggestions = json.loads(result)
        if isinstance(suggestions, list) and len(suggestions) >= 1:
            return suggestions[:3]
    except Exception as e:
        logger.error(f"AI建议生成失败: {e}")
    return ["已收到您的消息，医生会尽快回复。"]


@router.get("/history")
def get_history(doctor_id: int, patient_id: int, limit: int = 50, token: str = ""):
    """获取聊天记录
    安全：token存在则校验，无token仅demo（doctor_id=1）
    """
    if token:
        try:
            from app.core.security import verify_token
            verify_token(token)
        except HTTPException as e:
            raise e
    elif doctor_id != 1:
        raise HTTPException(403, "请先登录")

    db = SessionLocal()
    try:
        if not _check_binding(db, doctor_id, patient_id):
            raise HTTPException(403, "医患未绑定")
        msgs = db.query(ConsultationMessage).filter(
            ConsultationMessage.doctor_id == doctor_id,
            ConsultationMessage.patient_id == patient_id,
        ).order_by(ConsultationMessage.created_at.desc()).limit(limit).all()

        return [{
            "id": m.id,
            "sender_role": m.sender_role,
            "sender_id": m.sender_id,
            "msg_type": m.msg_type,
            "content": m.content,
            "is_read": m.is_read,
            "is_emergency": m.is_emergency,
            "ai_suggestions": json.loads(m.ai_suggestions or "[]"),
            "created_at": m.created_at.isoformat(),
        } for m in reversed(msgs)]
    finally:
        db.close()


@router.post("/read")
def mark_read(doctor_id: int, patient_id: int, sender_role: str = "doctor"):
    """标记消息已读"""
    db = SessionLocal()
    try:
        msgs = db.query(ConsultationMessage).filter(
            ConsultationMessage.doctor_id == doctor_id,
            ConsultationMessage.patient_id == patient_id,
            ConsultationMessage.sender_role != sender_role,
            ConsultationMessage.is_read == False
        ).all()
        for m in msgs:
            m.is_read = True
        db.commit()
        return {"success": True, "marked": len(msgs)}
    finally:
        db.close()


@router.get("/unread-count")
def unread_count(doctor_id: int, patient_id: Optional[int] = None):
    """未读消息数（医生端所有患者汇总 / 指定患者）"""
    db = SessionLocal()
    try:
        q = db.query(ConsultationMessage).filter(
            ConsultationMessage.doctor_id == doctor_id,
            ConsultationMessage.is_read == False
        )
        if patient_id:
            q = q.filter(ConsultationMessage.patient_id == patient_id)
        return {"unread": q.count()}
    finally:
        db.close()
