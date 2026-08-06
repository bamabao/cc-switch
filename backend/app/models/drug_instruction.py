"""
药品说明书数据库
存储结构化药品信息：成人用量、儿童用量、禁忌、说明书等
"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime
from .base import Base


class DrugInstruction(Base):
    """药品说明书结构化数据"""
    __tablename__ = "drug_instructions"

    id = Column(Integer, primary_key=True, index=True)
    medicine_name = Column(String(128), nullable=False, index=True, unique=True)
    
    # 基本信息
    category = Column(String(32), nullable=True)          # 分类：内服/外用/针剂
    standard_dosage = Column(String(255), nullable=True)  # 标准用量（成人）
    adult_dosage = Column(String(255), nullable=True)     # 成人详细用法
    child_dosage = Column(String(255), nullable=True)     # 儿童用量
    elderly_dosage = Column(String(255), nullable=True)   # 老人/特殊人群用量
    male_dosage = Column(String(255), nullable=True)      # 男性特有用量（如有）
    female_dosage = Column(String(255), nullable=True)    # 女性特有用量（如有）
    frequency = Column(String(64), nullable=True)         # 频次
    meal_relation = Column(String(64), nullable=True)     # 餐前/餐后/睡前
    max_daily = Column(String(128), nullable=True)        # 每日最大剂量
    
    # 禁忌与注意
    contraindications = Column(Text, nullable=True)        # 禁忌
    side_effects = Column(Text, nullable=True)            # 副作用
    dietary_restrictions = Column(Text, nullable=True)    # 饮食禁忌
    allergy_warning = Column(Text, nullable=True)         # 过敏警示
    
    # 说明书原文（纯文字）
    full_instruction = Column(Text, nullable=True)        # 完整说明书摘要
    precautions = Column(Text, nullable=True)              # 注意事项
    indications = Column(Text, nullable=True)              # 适应症
    
    # 元数据
    source = Column(String(32), default='manual')         # 数据来源：manual/volcano/dayi
    hit_count = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
