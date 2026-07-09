import enum
from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, DateTime, Boolean, Enum as SAEnum,
    ForeignKey, Float, Text, Time, Date, JSON
)
from sqlalchemy.orm import relationship
from .base import Base


class DrugCategory(str, enum.Enum):
    ORAL = "oral"              # 内服
    EXTERNAL = "external"      # 外用
    INJECTION = "injection"    # 针剂
    SUPPLEMENT = "supplement"  # 滋补辅药


class OralForm(str, enum.Enum):
    TABLET = "tablet"          # 药片
    CAPSULE = "capsule"        # 胶囊
    GRANULE = "granule"        # 冲剂
    ORAL_LIQUID = "oral_liquid"  # 口服液
    DECOCTION = "decoction"    # 中药汤剂


class ExternalForm(str, enum.Enum):
    OINTMENT = "ointment"       # 药膏
    SPRAY = "spray"             # 喷雾
    DROPS = "drops"             # 滴眼液
    PATCH = "patch"             # 贴剂
    IODOPHOR = "iodophor"       # 碘伏
    LOTION = "lotion"           # 洗剂


class InjectionForm(str, enum.Enum):
    INSULIN = "insulin"         # 胰岛素
    SUBCUTANEOUS = "subcutaneous"  # 皮下注射
    LONG_ACTING = "long_acting"  # 长效药剂
    INFUSION = "infusion"       # 输液


class MedicationStatus(str, enum.Enum):
    APPROVED = "approved"         # 已通过
    PENDING = "pending"           # 待审核（兼容旧数据）
    REJECTED = "rejected"         # 已拒绝（兼容旧数据）
    DISABLED = "disabled"       # 已停用


class Medication(Base):
    """药品档案"""
    __tablename__ = "medications"

    id = Column(Integer, primary_key=True, index=True)
    elder_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # 分类
    category = Column(SAEnum(DrugCategory), nullable=False)

    # 共通字段
    name = Column(String(128), nullable=False)
    manufacturer = Column(String(128), default="")
    expiry_date = Column(Date, nullable=True)
    total_quantity = Column(Float, nullable=True)  # 总剩余药量
    unit = Column(String(16), default="")  # 单位：片/粒/ml/袋/IU
    notes = Column(Text, default="")
    photo_urls = Column(JSON, default=list)  # 药盒/说明书拍照存档

    # 审核状态
    status = Column(SAEnum(MedicationStatus), default=MedicationStatus.APPROVED)
    created_by = Column(String(32), default="elder")  # elder | child
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 内服特有
    oral_form = Column(SAEnum(OralForm), nullable=True)
    dosage_per_take = Column(Float, nullable=True)  # 单次剂量
    frequency_per_day = Column(Integer, nullable=True)  # 每日频次
    meal_relation = Column(String(16), nullable=True)  # 饭前/饭后/空腹
    dietary_restrictions = Column(Text, default="")  # 忌口
    side_effects = Column(Text, default="")  # 不良反应

    # 外用特有
    external_form = Column(SAEnum(ExternalForm), nullable=True)
    application_site = Column(String(128), default="")  # 使用部位
    cycle_info = Column(String(128), default="")  # 涂抹/敷贴周期
    skin_allergy_warning = Column(String(256), default="")
    storage_requirement = Column(String(128), default="")

    # 针剂特有
    injection_form = Column(SAEnum(InjectionForm), nullable=True)
    injection_site = Column(String(128), default="")  # 注射部位
    injection_cycle = Column(String(32), default="")  # 每日/隔日/每周
    shake_before_use = Column(Boolean, default=False)
    hypoglycemia_warning = Column(String(256), default="")
    allergy_warning = Column(String(256), default="")

    # 滋补特有
    supplement_type = Column(String(32), default="")  # 降压滋补/保健调理

    # Relations
    elder = relationship("User", back_populates="medications")
    schedules = relationship("MedicationSchedule", back_populates="medication", cascade="all, delete-orphan")
    logs = relationship("MedicationLog", back_populates="medication", cascade="all, delete-orphan")


class MedicationSchedule(Base):
    """用药定时计划"""
    __tablename__ = "medication_schedules"

    id = Column(Integer, primary_key=True, index=True)
    medication_id = Column(Integer, ForeignKey("medications.id"), nullable=False, index=True)

    # 时间点
    time_of_day = Column(Time, nullable=False)           # 服用时段
    weekday_mask = Column(Integer, default=127)          # 每周哪几天 (bitmask 1=Mon...)
    dosage = Column(Float, nullable=False)                # 该次用量
    dosage_display = Column(String(32), default="")      # 可视化标注：半片、1/4片等

    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    medication = relationship("Medication", back_populates="schedules")


class MedicationLog(Base):
    """用药记录（确认/漏服流水）"""
    __tablename__ = "medication_logs"

    id = Column(Integer, primary_key=True, index=True)
    medication_id = Column(Integer, ForeignKey("medications.id"), nullable=False, index=True)
    elder_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    schedule_id = Column(Integer, ForeignKey("medication_schedules.id"), nullable=True)

    scheduled_time = Column(DateTime, nullable=False)      # 预定时间
    confirmed_time = Column(DateTime, nullable=True)       # 确认时间（NULL=漏服）
    status = Column(String(16), default="confirmed")       # confirmed | missed | double_warning
    dosage_taken = Column(Float, nullable=True)             # 实际服用剂量
    remark = Column(String(256), default="")                # 备注

    # 提醒记录
    reminder_sent_1 = Column(DateTime, nullable=True)       # 首次提醒
    reminder_sent_2 = Column(DateTime, nullable=True)       # 15分钟二次提醒
    alert_sent_to_child = Column(Boolean, default=False)    # 30分钟推送到子女

    created_at = Column(DateTime, default=datetime.utcnow)

    medication = relationship("Medication", back_populates="logs")
    elder = relationship("User")
