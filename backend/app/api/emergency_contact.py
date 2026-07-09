"""紧急联系人 CRUD API"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional

from app.models.base import get_db
from app.models.emergency_contact import EmergencyContact
from app.models.user import UserRole
from app.schemas.emergency_contact import (
    EmergencyContactCreate,
    EmergencyContactUpdate,
    EmergencyContactResponse,
    EmergencyContactListResponse,
)
from app.api.auth import get_current_user

router = APIRouter(prefix="/api/v1/emergency-contacts", tags=["紧急联系人"])


@router.get("", response_model=EmergencyContactListResponse)
def list_emergency_contacts(
    token: str = Query(...),
    elder_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    """获取紧急联系人列表（老人查看自己的，子女查看绑定老人的）"""
    user = get_current_user(token, db)

    target_elder_id = elder_id
    if target_elder_id is None:
        if user.role == UserRole.ELDER:
            target_elder_id = user.id
        else:
            raise HTTPException(400, "子女用户必须指定 elder_id")

    contacts = (
        db.query(EmergencyContact)
        .filter(
            EmergencyContact.elder_id == target_elder_id,
            EmergencyContact.is_active,
        )
        .order_by(EmergencyContact.priority)
        .order_by(EmergencyContact.created_at)
        .all()
    )
    return EmergencyContactListResponse(
        items=[EmergencyContactResponse.model_validate(c) for c in contacts],
        total=len(contacts),
    )


@router.post("", response_model=EmergencyContactResponse)
def create_emergency_contact(
    body: EmergencyContactCreate,
    token: str = Query(...),
    elder_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    """创建紧急联系人"""
    user = get_current_user(token, db)

    target_elder_id = elder_id
    if target_elder_id is None:
        if user.role == UserRole.ELDER:
            target_elder_id = user.id
        else:
            raise HTTPException(400, "子女用户必须指定 elder_id")

    contact = EmergencyContact(
        elder_id=target_elder_id,
        name=body.name,
        phone=body.phone,
        relation=body.relation or "",
        priority=body.priority or 0,
    )
    db.add(contact)
    db.commit()
    db.refresh(contact)
    return EmergencyContactResponse.model_validate(contact)


@router.get("/{contact_id}", response_model=EmergencyContactResponse)
def get_emergency_contact(
    contact_id: int,
    token: str = Query(...),
    db: Session = Depends(get_db),
):
    """获取单个紧急联系人详情"""
    get_current_user(token, db)
    contact = db.query(EmergencyContact).filter(EmergencyContact.id == contact_id).first()
    if not contact:
        raise HTTPException(404, "紧急联系人不存在")
    return EmergencyContactResponse.model_validate(contact)


@router.put("/{contact_id}", response_model=EmergencyContactResponse)
def update_emergency_contact(
    contact_id: int,
    body: EmergencyContactUpdate,
    token: str = Query(...),
    db: Session = Depends(get_db),
):
    """更新紧急联系人"""
    get_current_user(token, db)
    contact = db.query(EmergencyContact).filter(EmergencyContact.id == contact_id).first()
    if not contact:
        raise HTTPException(404, "紧急联系人不存在")

    if body.name is not None:
        contact.name = body.name
    if body.phone is not None:
        contact.phone = body.phone
    if body.relation is not None:
        contact.relation = body.relation
    if body.priority is not None:
        contact.priority = body.priority
    if body.is_active is not None:
        contact.is_active = body.is_active

    db.commit()
    db.refresh(contact)
    return EmergencyContactResponse.model_validate(contact)


@router.delete("/{contact_id}")
def delete_emergency_contact(
    contact_id: int,
    token: str = Query(...),
    db: Session = Depends(get_db),
):
    """删除紧急联系人（软删除）"""
    get_current_user(token, db)
    contact = db.query(EmergencyContact).filter(EmergencyContact.id == contact_id).first()
    if not contact:
        raise HTTPException(404, "紧急联系人不存在")
    contact.is_active = False
    db.commit()
    return {"message": "删除成功"}


@router.get("/primary/phone", response_model=dict)
def get_primary_contact_phone(
    token: str = Query(...),
    elder_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    """获取最高优先级联系人的电话号码（供紧急拨号使用）"""
    user = get_current_user(token, db)

    target_elder_id = elder_id
    if target_elder_id is None:
        if user.role == UserRole.ELDER:
            target_elder_id = user.id
        else:
            raise HTTPException(400, "子女用户必须指定 elder_id")

    contact = (
        db.query(EmergencyContact)
        .filter(
            EmergencyContact.elder_id == target_elder_id,
            EmergencyContact.is_active,
        )
        .order_by(EmergencyContact.priority)
        .first()
    )
    if not contact:
        return {"phone": None, "name": None}
    return {"phone": contact.phone, "name": contact.name}
