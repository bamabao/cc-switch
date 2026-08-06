"""药品说明书 Pydantic Schema"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class DrugInstructionOut(BaseModel):
    id: int
    medicine_name: str
    category: Optional[str] = None
    standard_dosage: Optional[str] = None
    adult_dosage: Optional[str] = None
    child_dosage: Optional[str] = None
    elderly_dosage: Optional[str] = None
    male_dosage: Optional[str] = None
    female_dosage: Optional[str] = None
    frequency: Optional[str] = None
    meal_relation: Optional[str] = None
    max_daily: Optional[str] = None
    contraindications: Optional[str] = None
    side_effects: Optional[str] = None
    dietary_restrictions: Optional[str] = None
    allergy_warning: Optional[str] = None
    full_instruction: Optional[str] = None
    precautions: Optional[str] = None
    indications: Optional[str] = None
    source: Optional[str] = "manual"
    hit_count: int = 1
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class DrugSearchResult(BaseModel):
    items: list[DrugInstructionOut]
    source: Optional[str] = None
