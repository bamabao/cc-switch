"""用药管理 API Schemas"""
from datetime import date, time, datetime
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict

from app.models.medication import DrugCategory, OralForm, ExternalForm, InjectionForm, MedicationStatus


# ========== 药品创建/更新 ==========

class ScheduleCreate(BaseModel):
    time_of_day: time
    dosage: float
    dosage_display: Optional[str] = ""
    weekday_mask: Optional[int] = 127


class MedicationCreate(BaseModel):
    category: DrugCategory

    # 共通
    name: str
    manufacturer: Optional[str] = ""
    expiry_date: Optional[date] = None
    total_quantity: Optional[float] = None
    unit: Optional[str] = ""
    notes: Optional[str] = ""
    photo_urls: Optional[List[str]] = []

    # 内服
    oral_form: Optional[OralForm] = None
    dosage_per_take: Optional[float] = None
    frequency_per_day: Optional[int] = None
    meal_relation: Optional[str] = None
    dietary_restrictions: Optional[str] = ""
    side_effects: Optional[str] = ""

    # 外用
    external_form: Optional[ExternalForm] = None
    application_site: Optional[str] = ""
    cycle_info: Optional[str] = ""
    skin_allergy_warning: Optional[str] = ""
    storage_requirement: Optional[str] = ""

    # 针剂
    injection_form: Optional[InjectionForm] = None
    injection_site: Optional[str] = ""
    injection_cycle: Optional[str] = ""
    shake_before_use: Optional[bool] = False
    hypoglycemia_warning: Optional[str] = ""
    allergy_warning: Optional[str] = ""

    # 滋补
    supplement_type: Optional[str] = ""

    # 定时计划
    schedules: List[ScheduleCreate] = []


class MedicationUpdate(BaseModel):
    name: Optional[str] = None
    manufacturer: Optional[str] = None
    expiry_date: Optional[date] = None
    total_quantity: Optional[float] = None
    unit: Optional[str] = None
    notes: Optional[str] = None
    photo_urls: Optional[List[str]] = None
    dosage_per_take: Optional[float] = None
    frequency_per_day: Optional[int] = None
    meal_relation: Optional[str] = None
    dietary_restrictions: Optional[str] = None
    side_effects: Optional[str] = None


# ========== 审核 ==========

class AuditActionRequest(BaseModel):
    action: str = Field(..., pattern="^(approve|reject)$")
    reject_reason: Optional[str] = ""


# ========== 响应 ==========

class ScheduleResponse(BaseModel):
    id: int
    time_of_day: str
    dosage: float
    dosage_display: str
    weekday_mask: int
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class MedicationResponse(BaseModel):
    id: int
    elder_id: int
    category: str
    name: str
    manufacturer: str
    expiry_date: Optional[date]
    total_quantity: Optional[float]
    unit: str
    status: str
    created_by: str
    notes: str
    photo_urls: list
    created_at: datetime
    updated_at: Optional[datetime]

    # 分类特有字段
    oral_form: Optional[str] = None
    dosage_per_take: Optional[float] = None
    frequency_per_day: Optional[int] = None
    meal_relation: Optional[str] = None
    dietary_restrictions: Optional[str] = ""
    side_effects: Optional[str] = ""

    external_form: Optional[str] = None
    application_site: Optional[str] = ""
    cycle_info: Optional[str] = ""
    skin_allergy_warning: Optional[str] = ""
    storage_requirement: Optional[str] = ""

    injection_form: Optional[str] = None
    injection_site: Optional[str] = ""
    injection_cycle: Optional[str] = ""
    shake_before_use: Optional[bool] = False
    hypoglycemia_warning: Optional[str] = ""
    allergy_warning: Optional[str] = ""

    supplement_type: Optional[str] = ""

    # 定时计划
    schedules: List[ScheduleResponse] = []

    model_config = ConfigDict(from_attributes=True)


# ========== 用药确认 ==========

class MedicationConfirm(BaseModel):
    medication_id: int
    schedule_id: int
    dosage_taken: Optional[float] = None
    remark: Optional[str] = ""
