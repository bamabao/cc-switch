"""
药品OCR识别缓存表

缓存火山视觉 / 高置信度本地OCR的结果，
下次同一药品名直接命中，无需重复OCR。
"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime
from .base import Base


class MedicineCache(Base):
    """药品OCR识别缓存"""
    __tablename__ = "medicine_cache"

    id = Column(Integer, primary_key=True, index=True)
    medicine_name = Column(String(128), nullable=False, index=True)
    dosage = Column(String(64), nullable=True)
    frequency = Column(String(64), nullable=True)
    category = Column(String(32), nullable=True)
    hit_count = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    source = Column(String(32), nullable=False, default='volcano_vision')
