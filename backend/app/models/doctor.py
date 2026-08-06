"""爸妈宝医生版 — 医生/助理/医患绑定/消息/套餐/审计模型"""
import enum
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Float, Text, Enum as SAEnum, ForeignKey
from sqlalchemy.orm import relationship
from .base import Base


class DoctorStatus(str, enum.Enum):
    PENDING = "pending"       # 待审核
    APPROVED = "approved"     # 已通过
    REJECTED = "rejected"     # 已拒绝
    SUSPENDED = "suspended"   # 已停用


class AssistantRole(str, enum.Enum):
    DOCTOR = "doctor"          # 执业医师（全权限助理）
    ASSISTANT_DOCTOR = "assistant_doctor"  # 执业助理医师
    NURSE = "nurse"            # 注册护士
    PHARMACIST = "pharmacist"  # 药师


class SubscriptionPlan(str, enum.Enum):
    FREE = "free"              # 免费版 ¥0
    PERSONAL = "personal"      # 个人版 ¥29/月
    STUDIO = "studio"          # 工作室版 ¥99/月
    HOSPITAL = "hospital"      # 医院版 ¥299/月
    PRIVATE = "private"        # 私有化部署


class Doctor(Base):
    """医生账号"""
    __tablename__ = "doctors"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String(20), unique=True, index=True, nullable=False)
    real_name = Column(String(64), default="")
    hospital = Column(String(128), default="")
    department = Column(String(64), default="")
    title = Column(String(32), default="")          # 职称：主任医师/副主任医师/主治医师
    license_no = Column(String(64), default="")     # 医师资格证号
    practice_no = Column(String(64), default="")    # 执业证书号
    id_card = Column(String(32), default="")        # 身份证号（加密存储）
    email = Column(String(128), default="")
    avatar_url = Column(String(256), default="")
    intro = Column(Text, default="")                # 简介
    status = Column(SAEnum(DoctorStatus), default=DoctorStatus.PENDING)

    # 资质文件路径
    license_photo = Column(String(256), default="")   # 资格证照片
    practice_photo = Column(String(256), default="")  # 执业证照片
    idcard_photo = Column(String(256), default="")    # 身份证照片

    # 套餐
    plan = Column(SAEnum(SubscriptionPlan), default=SubscriptionPlan.FREE)
    plan_expire_at = Column(DateTime, nullable=True)
    patient_quota = Column(Integer, default=10)   # 患者名额
    assistant_quota = Column(Integer, default=0)  # 助理名额

    # 工作时间（JSON字符串：{"mon":["08:00-18:00"],...}）
    work_hours = Column(Text, default="{}")
    auto_reply = Column(Text, default="")  # 非工作时间自动回复内容

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 关系
    patients = relationship("DoctorPatient", back_populates="doctor", foreign_keys="DoctorPatient.doctor_id")
    assistants = relationship("DoctorAssistant", back_populates="doctor", foreign_keys="DoctorAssistant.doctor_id")


class DoctorPatient(Base):
    """医患绑定关系"""
    __tablename__ = "doctor_patients"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(Integer, ForeignKey("doctors.id"), nullable=False, index=True)
    patient_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # 患者授权
    allow_view_checkin = Column(Boolean, default=True)   # 允许查看打卡
    allow_view_meds = Column(Boolean, default=True)      # 允许查看药品
    allow_history = Column(Boolean, default=True)        # 允许查看历史
    allow_contact = Column(Boolean, default=True)        # 允许主动联系
    allow_research = Column(Boolean, default=False)      # 允许科研使用
    auth_expire_at = Column(DateTime, nullable=True)     # 授权有效期

    # 权限级别
    access_level = Column(Integer, default=1)  # 1基础 2标准 3完整

    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    doctor = relationship("Doctor", back_populates="patients", foreign_keys=[doctor_id])


class DoctorAssistant(Base):
    """主治医生-助理医生 授权关系"""
    __tablename__ = "doctor_assistants"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(Integer, ForeignKey("doctors.id"), nullable=False, index=True)     # 主治医生
    assistant_id = Column(Integer, ForeignKey("doctors.id"), nullable=False, index=True)  # 助理医生
    role = Column(SAEnum(AssistantRole), default=AssistantRole.ASSISTANT_DOCTOR)

    # 权限
    can_reply = Column(Boolean, default=True)          # 可以回复
    can_view_data = Column(Boolean, default=True)      # 可以查看数据
    need_approval = Column(Boolean, default=True)      # 回复需主治审核
    patient_ids = Column(Text, default="[]")           # 分配的患者ID列表(JSON)

    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    revoked_at = Column(DateTime, nullable=True)

    doctor = relationship("Doctor", back_populates="assistants", foreign_keys=[doctor_id])


class ConsultationMessage(Base):
    """医患聊天消息"""
    __tablename__ = "consultation_messages"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(Integer, ForeignKey("doctors.id"), nullable=False, index=True)
    patient_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    sender_role = Column(String(16), default="patient")  # patient/doctor/assistant/system
    sender_id = Column(Integer, nullable=False)          # 发送者ID（患者ID或医生ID）
    msg_type = Column(String(16), default="text")        # text/image/audio/approval
    content = Column(Text, default="")
    is_read = Column(Boolean, default=False)
    is_emergency = Column(Boolean, default=False)        # 紧急消息标记
    ai_suggestions = Column(Text, default="[]")          # AI建议回复(JSON数组，医生端显示)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)


class MedicationApproval(Base):
    """用药审核记录"""
    __tablename__ = "medication_approvals"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(Integer, ForeignKey("doctors.id"), nullable=False, index=True)
    patient_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    medication_id = Column(Integer, nullable=False)      # 药品ID
    medication_name = Column(String(128), default="")
    status = Column(String(16), default="pending")       # pending/approved/rejected
    doctor_comment = Column(Text, default="")            # 医生意见
    ai_analysis = Column(Text, default="")               # AI分析摘要
    decided_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class Order(Base):
    """套餐订阅订单"""
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    order_no = Column(String(64), unique=True, index=True)
    doctor_id = Column(Integer, ForeignKey("doctors.id"), nullable=False, index=True)
    plan = Column(SAEnum(SubscriptionPlan), nullable=False)
    amount = Column(Float, default=0)
    months = Column(Integer, default=1)
    status = Column(String(16), default="pending")  # pending/paid/refunded/cancelled
    pay_method = Column(String(32), default="")     # wechat/alipay/bank
    paid_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class AuditLog(Base):
    """操作审计日志（等保三级要求≥180天）"""
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    actor_type = Column(String(16), default="")   # doctor/assistant/admin/patient
    actor_id = Column(Integer, default=0)
    action = Column(String(64), default="")       # view_patient/send_msg/approve_med/...
    target_type = Column(String(32), default="")
    target_id = Column(Integer, default=0)
    detail = Column(Text, default="")
    ip = Column(String(64), default="")
    created_at = Column(DateTime, default=datetime.utcnow, index=True)


class Prescription(Base):
    """医生开具的用药方案（电子处方）"""
    __tablename__ = "prescriptions"

    id = Column(Integer, primary_key=True, index=True)
    presc_no = Column(String(64), unique=True, index=True)   # 处方号
    doctor_id = Column(Integer, ForeignKey("doctors.id"), nullable=False, index=True)
    patient_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String(128), default="")      # 方案名称，如"高血压用药方案"
    summary = Column(Text, default="")            # 医生留言
    status = Column(String(16), default="pending")  # pending(已发送待接收)/accepted(已接收)/rejected(已拒绝)/expired
    disease_group = Column(String(64), default="")   # 病种组
    items_json = Column(Text, default="[]")       # 药品明细JSON数组
    received_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    doctor = relationship("Doctor", foreign_keys=[doctor_id])


class PrescriptionItem(Base):
    """处方明细（一颗药的完整用法）"""
    __tablename__ = "prescription_items"

    id = Column(Integer, primary_key=True, index=True)
    prescription_id = Column(Integer, ForeignKey("prescriptions.id"), nullable=False, index=True)
    drug_name = Column(String(128), nullable=False)        # 药品名称
    category = Column(String(32), default="oral")          # oral/external/injection/supplement
    dosage_per_take = Column(Float, default=1)             # 单次剂量
    unit = Column(String(16), default="粒")                # 片/粒/ml/袋/丸
    frequency_per_day = Column(Integer, default=3)         # 每日频次
    times_json = Column(String(64), default='["08:00","12:00","18:00"]')  # 服药时间
    meal_relation = Column(String(16), default="")         # 饭前/饭后/空腹
    duration_days = Column(Integer, default=7)             # 疗程天数
    notes = Column(Text, default="")                       # 用药说明
    total_quantity = Column(Float, default=0)              # 总量
    created_at = Column(DateTime, default=datetime.utcnow)
