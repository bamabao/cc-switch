from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, Enum as SAEnum
from .base import Base
import enum


class AuditAction(str, enum.Enum):
    CREATE = "create"         # 新增药品
    UPDATE = "update"         # 修改药品
    SUBMIT = "submit"         # 提交审核
    APPROVE = "approve"       # 审核通过
    REJECT = "reject"         # 驳回


class AuditRecord(Base):
    """全程操作留痕"""
    __tablename__ = "audit_records"

    id = Column(Integer, primary_key=True, index=True)
    medication_id = Column(Integer, ForeignKey("medications.id"), index=True, nullable=False)
    actor_id = Column(Integer, ForeignKey("users.id"), nullable=False)  # 操作人
    action = Column(SAEnum(AuditAction), nullable=False)
    detail = Column(Text, default="")       # 变更内容描述
    reject_reason = Column(Text, default="")  # 驳回原因
    created_at = Column(DateTime, default=datetime.utcnow)
