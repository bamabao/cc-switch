"""爸妈宝 — 健康指标数据模型（血压/血糖/尿酸/心率/血氧/体温）
为未来穿戴设备（手表/指环/血糖仪）预留统一数据协议
"""
import enum
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Float, Text, Enum as SAEnum, ForeignKey
from .base import Base


class MetricType(str, enum.Enum):
    BP = "blood_pressure"        # 血压 (收缩压/舒张压)
    GLUCOSE = "blood_glucose"    # 血糖 (mmol/L)
    URIC_ACID = "uric_acid"      # 尿酸 (μmol/L)
    HR = "heart_rate"            # 心率 (次/分)
    SPO2 = "spo2"                # 血氧 (%)
    TEMP = "temperature"         # 体温 (℃)
    HRV = "hrv"                  # 心率变异性 (ms)
    RESP = "respiration"         # 呼吸率 (次/分)
    SLEEP = "sleep"              # 睡眠 (分钟/评分)
    STEPS = "steps"              # 步数


class DeviceSource(str, enum.Enum):
    MANUAL = "manual"            # 手动录入
    WEARABLE = "wearable"        # 穿戴设备（手表/戒指）
    BGM = "bgm"                  # 血糖仪
    BP_MONITOR = "bp_monitor"    # 血压计
    APP = "app"                  # App内置


class HealthMetric(Base):
    """健康指标记录（统一表，type 区分指标类型）"""
    __tablename__ = "health_metrics"

    id = Column(Integer, primary_key=True, index=True)
    elder_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    metric_type = Column(SAEnum(MetricType), nullable=False, index=True)  # 指标类型
    value = Column(Float, nullable=False)          # 主数值
    value2 = Column(Float, nullable=True)          # 副数值（如血压舒张压）
    unit = Column(String(16), default="")          # 单位
    measured_at = Column(DateTime, nullable=False, index=True)  # 测量时间

    # 设备来源（穿戴生态）
    source = Column(SAEnum(DeviceSource), default=DeviceSource.MANUAL)
    device_id = Column(String(64), default="")     # 设备唯一标识（手表MAC/戒指序列号）
    device_model = Column(String(64), default="")  # 设备型号（如 Oura Ring 5 / 爸妈宝Watch）

    # 附加上下文
    context = Column(String(16), default="")       # 空腹/餐后/睡前/晨起等
    note = Column(Text, default="")                # 备注

    # 原始数据JSON（设备上报的完整载荷，备用）
    raw_json = Column(Text, default="")

    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    def to_dict(self):
        return {
            "id": self.id,
            "elder_id": self.elder_id,
            "metric_type": self.metric_type.value,
            "value": self.value,
            "value2": self.value2,
            "unit": self.unit,
            "measured_at": self.measured_at.isoformat() if self.measured_at else None,
            "source": self.source.value if self.source else "manual",
            "device_id": self.device_id,
            "device_model": self.device_model,
            "context": self.context,
            "note": self.note,
        }


# 指标显示配置（前端渲染用）
METRIC_CONFIG = {
    MetricType.BP: {"label": "血压", "unit": "mmHg", "icon": "🩺", "normal": "90-139/60-89"},
    MetricType.GLUCOSE: {"label": "血糖", "unit": "mmol/L", "icon": "🩸", "normal": "空腹3.9-6.1"},
    MetricType.URIC_ACID: {"label": "尿酸", "unit": "μmol/L", "icon": "🧬", "normal": "男<420 女<360"},
    MetricType.HR: {"label": "心率", "unit": "次/分", "icon": "❤️", "normal": "60-100"},
    MetricType.SPO2: {"label": "血氧", "unit": "%", "icon": "🫁", "normal": "≥95"},
    MetricType.TEMP: {"label": "体温", "unit": "℃", "icon": "🌡️", "normal": "36.0-37.2"},
    MetricType.HRV: {"label": "心率变异性", "unit": "ms", "icon": "📈", "normal": "20-100"},
    MetricType.RESP: {"label": "呼吸率", "unit": "次/分", "icon": "🌬️", "normal": "12-20"},
    MetricType.SLEEP: {"label": "睡眠", "unit": "分", "icon": "😴", "normal": "≥420"},
    MetricType.STEPS: {"label": "步数", "unit": "步", "icon": "🚶", "normal": "≥6000"},
}
