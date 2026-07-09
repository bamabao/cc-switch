from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.models.base import get_db
from app.models.audit import AuditRecord
from app.models.medication import Medication

router = APIRouter(prefix="/api/v1/audit", tags=["审核日志"])


@router.get("/history")
def get_audit_history(
    elder_id: int = Query(...),
    medication_id: Optional[int] = Query(None),
    days: int = Query(30),
    db: Session = Depends(get_db),
):
    """获取操作留痕记录（子女端溯源查询）"""
    since = datetime.utcnow() - timedelta(days=days)
    q = (
        db.query(AuditRecord)
        .join(Medication, AuditRecord.medication_id == Medication.id)
        .filter(Medication.elder_id == elder_id, AuditRecord.created_at >= since)
        .order_by(AuditRecord.created_at.desc())
    )
    if medication_id:
        q = q.filter(AuditRecord.medication_id == medication_id)

    records = q.all()
    return {
        "items": [
            {
                "id": r.id,
                "medication_id": r.medication_id,
                "actor_id": r.actor_id,
                "action": r.action.value,
                "detail": r.detail,
                "reject_reason": r.reject_reason,
                "created_at": r.created_at.isoformat(),
            }
            for r in records
        ],
        "total": len(records),
    }
