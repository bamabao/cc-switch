import enum
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Enum as SAEnum, ForeignKey, Float, Text
from sqlalchemy.orm import relationship
from .base import Base


class UserRole(str, enum.Enum):
    ELDER = "elder"  # 老人
    CHILD = "child"  # 子女


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    openid = Column(String(64), unique=True, index=True, nullable=True)  # 微信OpenID
    phone = Column(String(20), unique=True, nullable=True)
    nickname = Column(String(64), default="")
    avatar_url = Column(String(256), default="")
    role = Column(SAEnum(UserRole), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 老人端额外字段
    voice_preference = Column(String(32), default="mandarin")  # 方言/普通话
    font_scale = Column(Integer, default=200)  # 字号缩放百分比

    # Streak tracking
    current_streak = Column(Integer, default=0)
    longest_streak = Column(Integer, default=0)
    last_medication_date = Column(DateTime, nullable=True)
    total_points = Column(Integer, default=0)

    # Relations
    family_bindings_as_elder = relationship("FamilyBinding", foreign_keys="FamilyBinding.elder_id", back_populates="elder")
    family_bindings_as_child = relationship("FamilyBinding", foreign_keys="FamilyBinding.child_id", back_populates="child")
    medications = relationship("Medication", back_populates="elder")


class FamilyBinding(Base):
    """老人-子女绑定关系"""
    __tablename__ = "family_bindings"

    id = Column(Integer, primary_key=True, index=True)
    elder_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    child_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    relation_label = Column(String(32), default="")  # 关系标注
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # 注意：不能用 relationship 作为字段名，会与 sqlalchemy.orm.relationship 冲突
    elder = relationship("User", foreign_keys=[elder_id], back_populates="family_bindings_as_elder")
    child = relationship("User", foreign_keys=[child_id], back_populates="family_bindings_as_child")
