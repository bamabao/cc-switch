"""爸妈宝 — 睡眠监测模型
对标 Oura Ring：睡眠评分 + 分期(深睡/浅睡/REM/清醒) + 时长 + 心率/血氧基线
穿戴设备（指环/手表）每日上报一条
"""
import enum
from datetime import datetime, date
from sqlalchemy import Column, Integer, String, DateTime, Float, Text, Enum as SAEnum, Date, ForeignKey
from .base import Base


class SleepStage(str, enum.Enum):
    DEEP = "deep"        # 深睡
    LIGHT = "light"      # 浅睡
    REM = "rem"          # 快速眼动
    AWAKE = "awake"      # 清醒


class SleepRecord(Base):
    """每日睡眠记录（一天一条，由设备汇总上报）"""
    __tablename__ = "sleep_records"

    id = Column(Integer, primary_key=True, index=True)
    elder_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    sleep_date = Column(Date, nullable=False, index=True)   # 入睡那天的日期

    # 核心指标
    sleep_score = Column(Integer, default=0)                # 睡眠评分 0-100
    total_minutes = Column(Integer, default=0)              # 总睡眠时长(分钟)
    deep_minutes = Column(Integer, default=0)               # 深睡
    light_minutes = Column(Integer, default=0)              # 浅睡
    rem_minutes = Column(Integer, default=0)                # REM
    awake_minutes = Column(Integer, default=0)              # 清醒
    efficiency = Column(Float, default=0)                   # 睡眠效率 % (睡着时间/卧床时间)

    # 时间
    bedtime = Column(String(16), default="")                # 入睡时间 22:30
    wake_time = Column(String(16), default="")              # 醒来时间 06:30
    latency_minutes = Column(Integer, default=0)            # 入睡耗时(分钟)

    # 身体基线（穿戴设备采集）
    avg_hr = Column(Float, default=0)                       # 平均心率
    lowest_hr = Column(Float, default=0)                    # 最低心率
    avg_hrv = Column(Float, default=0)                      # 平均HRV
    avg_spo2 = Column(Float, default=0)                     # 平均血氧
    breathing_disturbances = Column(Integer, default=0)     # 呼吸中断次数

    # 来源
    source = Column(String(16), default="manual")           # manual / wearable
    device_id = Column(String(64), default="")
    device_model = Column(String(64), default="")

    # 原始数据
    stages_json = Column(Text, default="[]")                # 分期明细JSON
    raw_json = Column(Text, default="")                     # 设备原始载荷

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "elder_id": self.elder_id,
            "sleep_date": self.sleep_date.isoformat() if self.sleep_date else None,
            "sleep_score": self.sleep_score,
            "total_minutes": self.total_minutes,
            "deep_minutes": self.deep_minutes,
            "light_minutes": self.light_minutes,
            "rem_minutes": self.rem_minutes,
            "awake_minutes": self.awake_minutes,
            "efficiency": self.efficiency,
            "bedtime": self.bedtime,
            "wake_time": self.wake_time,
            "latency_minutes": self.latency_minutes,
            "avg_hr": self.avg_hr,
            "lowest_hr": self.lowest_hr,
            "avg_hrv": self.avg_hrv,
            "avg_spo2": self.avg_spo2,
            "breathing_disturbances": self.breathing_disturbances,
            "source": self.source,
            "device_model": self.device_model,
        }


def sleep_score_label(score: int) -> str:
    """睡眠评分等级（对标Oura）"""
    if score >= 85: return "优秀"
    if score >= 70: return "良好"
    if score >= 60: return "一般"
    if score >= 45: return "较差"
    return "很差"
