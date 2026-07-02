"""紧急联系人模型"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey
from .base import Base


class EmergencyContact(Base):
    """紧急联系人"""
    __tablename__ = "emergency_contacts"

    id = Column(Integer, primary_key=True, index=True)
    elder_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(32), nullable=False)
    phone = Column(String(20), nullable=False)
    relation = Column(String(32), default="")  # 关系：儿子/女儿/配偶/邻居/其他
    priority = Column(Integer, default=0)  # 优先级：0=最高
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
