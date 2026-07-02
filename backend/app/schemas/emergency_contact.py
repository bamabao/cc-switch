"""紧急联系人 API Schemas"""
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict


class EmergencyContactCreate(BaseModel):
    name: str
    phone: str
    relation: Optional[str] = ""
    priority: Optional[int] = 0


class EmergencyContactUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    relation: Optional[str] = None
    priority: Optional[int] = None
    is_active: Optional[bool] = None


class EmergencyContactResponse(BaseModel):
    id: int
    elder_id: int
    name: str
    phone: str
    relation: str
    priority: int
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class EmergencyContactListResponse(BaseModel):
    items: List[EmergencyContactResponse]
    total: int
