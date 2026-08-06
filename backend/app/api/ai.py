"""爸妈宝 AI 智能 API - 用药问答、相互作用检测、智能报告"""
import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from app.services.ai_service import ask_drug_question, check_drug_interaction, generate_weekly_report, check_emergency
from app.models.base import SessionLocal
from app.models.drug_instruction import DrugInstruction
from app.models.medication import MedicationLog

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/ai", tags=["ai"])


class DrugQuestion(BaseModel):
    question: str = Field(..., min_length=1, max_length=500)
    drug_name: Optional[str] = ""


class InteractionCheck(BaseModel):
    drugs: list[str] = Field(..., min_length=2)


# ─── 用药问答 ───

@router.post("/ask")
def ask_about_drug(req: DrugQuestion):
    """AI 用药问答"""
    context = ""
    if req.drug_name:
        db = SessionLocal()
        try:
            drug = db.query(DrugInstruction).filter(
                DrugInstruction.medicine_name.like(f"%{req.drug_name}%")
            ).first()
            if drug:
                context = (
                    f"适应症：{drug.indications or '未知'}\n"
                    f"禁忌：{drug.contraindications or '未知'}\n"
                    f"注意事项：{drug.precautions or '未知'}\n"
                    f"成人用量：{drug.adult_dosage or '未知'}"
                )
        finally:
            db.close()

    # 紧急关键词检测
    is_emergency = check_emergency(req.question)
    emergency_warning = ""
    if is_emergency:
        emergency_warning = "⚠️ 检测到您描述的症状可能属于紧急情况，请立即拨打120或前往最近医院就诊！"

    answer = ask_drug_question(req.question, req.drug_name, context)
    
    # 拼接免责声明
    disclaimer = "\n\n——\n🤖 以上由AI生成，仅供参考，请以医生诊断为准。"
    if emergency_warning:
        answer = f"{emergency_warning}\n\n{answer}{disclaimer}"
    else:
        answer = f"{answer}{disclaimer}"

    return {"answer": answer, "has_context": bool(context), "is_emergency": is_emergency}


# ─── 药物相互作用 ───

@router.post("/interaction")
def drug_interaction(req: InteractionCheck):
    """检查多种药物之间的相互作用"""
    result = check_drug_interaction(req.drugs)
    return {"drugs": req.drugs, "result": result}


# ─── 智能周报 ───

@router.get("/weekly-report/{elder_id}")
def weekly_report(elder_id: int):
    """生成每周用药报告"""
    from datetime import datetime, timedelta
    
    db = SessionLocal()
    try:
        week_ago = datetime.now() - timedelta(days=7)
        logs = db.query(MedicationLog).filter(
            MedicationLog.elder_id == elder_id,
            MedicationLog.taken_at >= week_ago,
        ).all()
        
        checkin_data = [
            {
                "medication_id": log.medication_id,
                "taken_at": log.taken_at.isoformat(),
                "status": log.status,
            }
            for log in logs[-50:]  # 最多取50条
        ]
        
        report = generate_weekly_report(checkin_data)
        return {
            "elder_id": elder_id,
            "report": report,
            "total_checkins": len(checkin_data),
            "period": f"{week_ago.strftime('%m-%d')} ~ {datetime.now().strftime('%m-%d')}",
        }
    finally:
        db.close()
