"""药品管理 API"""
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.models.base import get_db
from app.models.medication import (
    Medication, MedicationSchedule, MedicationLog,
    MedicationStatus, DrugCategory, OralForm, ExternalForm, InjectionForm
)
from app.models.audit import AuditRecord, AuditAction
from app.models.user import User, UserRole
from app.schemas.medication import (
    MedicationCreate, MedicationUpdate, MedicationResponse,
    MedicationConfirm, ScheduleResponse, AuditActionRequest
)

router = APIRouter(prefix="/api/v1/medications", tags=["药品管理"])


# ========== 内部辅助 ==========

def _get_elder(db, elder_id: int) -> User:
    user = db.query(User).filter(User.id == elder_id, User.role == UserRole.ELDER).first()
    if not user:
        raise HTTPException(404, "老人用户不存在")
    return user


def _get_medication(db, medication_id: int, elder_id: Optional[int] = None) -> Medication:
    q = db.query(Medication).filter(Medication.id == medication_id)
    if elder_id is not None:
        q = q.filter(Medication.elder_id == elder_id)
    med = q.first()
    if not med:
        raise HTTPException(404, "药品不存在")
    return med


def _to_medication_response(med: Medication) -> dict:
    """将 ORM 模型转为响应字典"""
    schedules = [
        ScheduleResponse(
            id=s.id,
            time_of_day=s.time_of_day.strftime("%H:%M"),
            dosage=s.dosage,
            dosage_display=s.dosage_display,
            weekday_mask=s.weekday_mask,
            is_active=s.is_active,
        )
        for s in med.schedules
    ]
    resp = MedicationResponse(
        id=med.id,
        elder_id=med.elder_id,
        category=med.category.value,
        name=med.name,
        manufacturer=med.manufacturer or "",
        expiry_date=med.expiry_date,
        total_quantity=med.total_quantity,
        unit=med.unit or "",
        status=med.status.value,
        created_by=med.created_by or "elder",
        notes=med.notes or "",
        photo_urls=med.photo_urls or [],
        created_at=med.created_at,
        updated_at=med.updated_at,
        schedules=schedules,

        oral_form=med.oral_form.value if med.oral_form else None,
        dosage_per_take=med.dosage_per_take,
        frequency_per_day=med.frequency_per_day,
        meal_relation=med.meal_relation,
        dietary_restrictions=med.dietary_restrictions or "",
        side_effects=med.side_effects or "",
        external_form=med.external_form.value if med.external_form else None,
        application_site=med.application_site or "",
        cycle_info=med.cycle_info or "",
        skin_allergy_warning=med.skin_allergy_warning or "",
        storage_requirement=med.storage_requirement or "",
        injection_form=med.injection_form.value if med.injection_form else None,
        injection_site=med.injection_site or "",
        injection_cycle=med.injection_cycle or "",
        shake_before_use=med.shake_before_use or False,
        hypoglycemia_warning=med.hypoglycemia_warning or "",
        allergy_warning=med.allergy_warning or "",
        supplement_type=med.supplement_type or "",
    )
    return resp.model_dump()


# ========== 药品 CRUD ==========

@router.get("")
def list_medications(
    elder_id: int = Query(..., description="老人用户ID"),
    category: Optional[str] = Query(None, description="药品分类筛选"),
    status: Optional[str] = Query(None, description="审核状态"),
    db: Session = Depends(get_db),
):
    """获取老人的药品列表"""
    _get_elder(db, elder_id)
    q = db.query(Medication).filter(Medication.elder_id == elder_id)
    if category:
        q = q.filter(Medication.category == DrugCategory(category))
    if status:
        q = q.filter(Medication.status == MedicationStatus(status))
    q = q.order_by(Medication.created_at.desc())
    return {"items": [_to_medication_response(m) for m in q.all()]}


@router.get("/pending")
def list_pending_medications(
    elder_id: int = Query(..., description="老人用户ID"),
    db: Session = Depends(get_db),
):
    """获取待审核药品列表（子女端审核入口）"""
    q = db.query(Medication).filter(
        Medication.elder_id == elder_id,
        Medication.status == MedicationStatus.PENDING,
    ).order_by(Medication.created_at.asc())
    return {"items": [_to_medication_response(m) for m in q.all()],
            "total": q.count()}


@router.get("/alerts")
def get_medication_alerts(
    elder_id: int = Query(...),
    db: Session = Depends(get_db),
):
    """
    获取老人的药品预警列表
    - 过期预警（expiry）：药品距离保质期不足30天
    - 余量预警（stock）：药品剩余用量不足7天
    - 已过期（expired）：已过保质期
    """
    from datetime import date, timedelta
    today = date.today()

    q = db.query(Medication).filter(
        Medication.elder_id == elder_id,
        Medication.status != MedicationStatus.DISABLED,
    )
    meds = q.all()

    alerts = []
    for med in meds:
        alerts_for_med = []

        if med.expiry_date:
            days_remaining = (med.expiry_date - today).days
            if days_remaining < 0:
                alerts_for_med.append({
                    "type": "expired",
                    "severity": "danger",
                    "message": f"药品「{med.name}」已于{med.expiry_date}过期",
                    "days_remaining": days_remaining,
                })
            elif days_remaining <= 30:
                alerts_for_med.append({
                    "type": "expiry",
                    "severity": "warning",
                    "message": f"药品「{med.name}」将在{days_remaining}天后过期",
                    "days_remaining": days_remaining,
                })

        if med.total_quantity and med.frequency_per_day and med.dosage_per_take and med.dosage_per_take > 0:
            daily_consumption = med.frequency_per_day * med.dosage_per_take
            if daily_consumption > 0:
                days_left = int(med.total_quantity / daily_consumption)
                if days_left <= 7:
                    alerts_for_med.append({
                        "type": "stock",
                        "severity": "warning" if days_left > 0 else "danger",
                        "message": f"药品「{med.name}」余量不足（约{days_left}天用量）",
                        "stock_days": days_left,
                    })

        if alerts_for_med:
            alerts.append({
                "medication_id": med.id,
                "medication_name": med.name,
                "alerts": alerts_for_med,
            })

    return {"items": alerts, "total": len(alerts)}


@router.get("/{medication_id}")
def get_medication(medication_id: int, elder_id: int = Query(...), db: Session = Depends(get_db)):
    """获取单个药品详情"""
    med = _get_medication(db, medication_id, elder_id)
    return _to_medication_response(med)


@router.post("", status_code=201)
def create_medication(
    elder_id: int = Query(...),
    body: MedicationCreate = None,
    db: Session = Depends(get_db),
):
    """老人/子女新增药品"""
    elder = _get_elder(db, elder_id)

    # 检查是否同名药品已存在
    existing = db.query(Medication).filter(
        Medication.elder_id == elder_id,
        Medication.name == body.name,
        Medication.status != MedicationStatus.DISABLED,
    ).first()
    if existing:
        raise HTTPException(400, f"药品「{body.name}」已存在")

    # 创建药品记录
    create_data = body.model_dump(exclude={"schedules"}, exclude_none=True)
    # 处理枚举字段
    for enum_field in ["category"]:
        if enum_field in create_data:
            create_data[enum_field] = DrugCategory(create_data[enum_field])
    form_class_map = {
        "oral_form": OralForm,
        "external_form": ExternalForm,
        "injection_form": InjectionForm,
    }
    for form_field, form_class in form_class_map.items():
        if form_field in create_data and create_data.get(form_field):
            try:
                create_data[form_field] = form_class(create_data[form_field])
            except ValueError:
                raise HTTPException(400, f"无效的{form_field}值: {create_data[form_field]}")

    med = Medication(elder_id=elder_id, **create_data)
    db.add(med)
    db.flush()  # 获取 id

    # 创建定时计划
    for s in body.schedules:
        schedule = MedicationSchedule(
            medication_id=med.id,
            time_of_day=s.time_of_day,
            dosage=s.dosage,
            dosage_display=s.dosage_display or "",
            weekday_mask=s.weekday_mask or 127,
        )
        db.add(schedule)

    # 记录操作
    audit = AuditRecord(
        medication_id=med.id,
        actor_id=elder_id,
        action=AuditAction.CREATE,
        detail=f"新增药品：{body.name}",
    )
    db.add(audit)
    db.commit()
    db.refresh(med)

    return _to_medication_response(med)


@router.put("/{medication_id}")
def update_medication(
    medication_id: int,
    elder_id: int = Query(...),
    body: MedicationUpdate = None,
    db: Session = Depends(get_db),
):
    """修改药品信息（进入待审核状态）"""
    med = _get_medication(db, medication_id, elder_id)

    update_data = body.model_dump(exclude_none=True)
    for k, v in update_data.items():
        setattr(med, k, v)

    # 修改后重置为待审核（除非是子女直接操作）
    if med.status == MedicationStatus.APPROVED:
        med.status = MedicationStatus.PENDING

    audit = AuditRecord(
        medication_id=med.id,
        actor_id=elder_id,
        action=AuditAction.UPDATE,
        detail=f"修改药品信息：{', '.join(update_data.keys())}",
    )
    db.add(audit)
    db.commit()
    db.refresh(med)
    return _to_medication_response(med)


# ========== 药品提交 & 审核 ==========

@router.post("/{medication_id}/submit")
def submit_medication(
    medication_id: int,
    elder_id: int = Query(...),
    db: Session = Depends(get_db),
):
    """老人提交药品审核"""
    med = _get_medication(db, medication_id, elder_id)
    if med.status == MedicationStatus.APPROVED:
        raise HTTPException(400, "该药品已审核通过，无需重复提交")

    med.status = MedicationStatus.PENDING
    audit = AuditRecord(
        medication_id=med.id,
        actor_id=elder_id,
        action=AuditAction.SUBMIT,
        detail="提交审核",
    )
    db.add(audit)
    db.commit()
    return {"message": "已提交审核", "status": "pending"}


@router.delete("/{medication_id}")
def delete_medication(
    medication_id: int,
    db: Session = Depends(get_db),
):
    """删除药品（仅DRAFT/PENDING状态可删）"""
    med = db.query(Medication).filter(Medication.id == medication_id).first()
    if not med:
        raise HTTPException(404, "药品不存在")
    if med.status == MedicationStatus.APPROVED or med.status == MedicationStatus.DISABLED:
        raise HTTPException(400, "已通过的药品不可删除，请先联系子女")
    # 删除关联记录（含审计、订单、日志）
    from app.models.audit import AuditRecord
    from app.models.point import PointTransaction, PointOrder
    db.query(AuditRecord).filter(AuditRecord.medication_id == medication_id).delete()
    db.query(MedicationLog).filter(MedicationLog.medication_id == medication_id).delete()
    db.query(MedicationSchedule).filter(MedicationSchedule.medication_id == medication_id).delete()
    db.delete(med)
    db.commit()
    return {"message": "已删除", "id": medication_id}


@router.post("/{medication_id}/audit")
def audit_medication(
    medication_id: int,
    child_id: int = Query(...),
    body: AuditActionRequest = None,
    db: Session = Depends(get_db),
):
    """子女审核药品"""
    med = _get_medication(db, medication_id)

    if body.action == "approve":
        med.status = MedicationStatus.APPROVED
        audit = AuditRecord(
            medication_id=med.id,
            actor_id=child_id,
            action=AuditAction.APPROVE,
            detail="审核通过",
        )
    elif body.action == "reject":
        med.status = MedicationStatus.REJECTED
        audit = AuditRecord(
            medication_id=med.id,
            actor_id=child_id,
            action=AuditAction.REJECT,
            detail="驳回",
            reject_reason=body.reject_reason or "",
        )

    db.add(audit)
    db.commit()
    return {"message": f"操作成功：{body.action}", "status": med.status.value}


# ========== 用药确认 ==========

@router.post("/confirm")
def confirm_medication(
    body: MedicationConfirm = None,
    elder_id: int = Query(...),
    db: Session = Depends(get_db),
):
    """老人确认用药完成"""
    now = datetime.utcnow()
    med = _get_medication(db, body.medication_id, elder_id)
    schedule = db.query(MedicationSchedule).filter(
        MedicationSchedule.id == body.schedule_id,
        MedicationSchedule.medication_id == med.id,
    ).first()
    if not schedule:
        raise HTTPException(404, "定时计划不存在")

    log = MedicationLog(
        medication_id=med.id,
        elder_id=elder_id,
        schedule_id=schedule.id,
        scheduled_time=datetime.combine(now.date(), schedule.time_of_day),
        confirmed_time=now,
        status="confirmed",
        dosage_taken=body.dosage_taken or schedule.dosage,
        remark=body.remark or "",
    )
    db.add(log)

    # 更新积分 + 连续打卡
    user = db.query(User).filter(User.id == elder_id).first()
    points_to_add = 10
    if user.total_points is None:
        user.total_points = 0
    user.total_points += points_to_add

    # 创建积分流水
    from app.models.point import PointTransaction, TransactionType
    tx = PointTransaction(
        elder_id=elder_id,
        type=TransactionType.REWARD_DOSE,
        amount=points_to_add,
        balance_after=user.total_points,
        description=f"按时用药奖励：{med.name}",
    )
    db.add(tx)
    yesterday = datetime(now.year, now.month, now.day)
    if user.last_medication_date:
        last = user.last_medication_date
        diff = (yesterday - last).days
        if diff == 1:
            user.current_streak += 1
        elif diff > 1:
            user.current_streak = 1
    else:
        user.current_streak = 1

    if user.current_streak > user.longest_streak:
        user.longest_streak = user.current_streak
    user.last_medication_date = now

    db.commit()
    return {"message": "用药已确认", "points_earned": 10}


# ========== 记录查询 ==========

@router.get("/logs/history")
def get_medication_logs(
    elder_id: int = Query(...),
    medication_id: Optional[int] = Query(None),
    days: int = Query(7, description="查询最近N天"),
    db: Session = Depends(get_db),
):
    """用药历史台账"""
    from datetime import timedelta
    since = datetime.utcnow() - timedelta(days=days)

    q = db.query(MedicationLog).filter(
        MedicationLog.elder_id == elder_id,
        MedicationLog.scheduled_time >= since,
    ).order_by(MedicationLog.scheduled_time.desc())

    if medication_id:
        q = q.filter(MedicationLog.medication_id == medication_id)

    logs = q.all()
    return {
        "total": len(logs),
        "confirmed": sum(1 for l in logs if l.status == "confirmed"),
        "missed": sum(1 for l in logs if l.status == "missed"),
        "items": [
            {
                "id": l.id,
                "medication_name": l.medication.name,
                "scheduled_time": l.scheduled_time.isoformat(),
                "confirmed_time": l.confirmed_time.isoformat() if l.confirmed_time else None,
                "status": l.status,
                "dosage_taken": l.dosage_taken,
            }
            for l in logs
        ],
    }


