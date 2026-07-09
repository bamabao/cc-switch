"""药品管理 API"""
from datetime import date, datetime, timedelta, time as dt_time
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.models.base import get_db
from app.models.medication import (
    Medication, MedicationSchedule, MedicationLog,
    MedicationStatus, DrugCategory, OralForm, ExternalForm, InjectionForm
)
from app.models.user import User, UserRole
from app.schemas.medication import (
    MedicationCreate, MedicationUpdate, MedicationResponse,
    MedicationConfirm, ScheduleResponse,
    CheckinRequest, CheckinUndoRequest,
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


# ========== 打卡查询 ==========

@router.get("/checkin/today")
def get_today_checkin(
    elder_id: int = Query(...),
    db: Session = Depends(get_db),
):
    """查询老人今天已打卡/待打卡状态（首页刷新用）"""
    _get_elder(db, elder_id)

    # 查询老人所有 active 药品
    meds = db.query(Medication).filter(
        Medication.elder_id == elder_id,
        Medication.status != MedicationStatus.DISABLED,
    ).all()

    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)

    items = []
    total_pending = 0

    for med in meds:
        schedules = med.schedules
        if not schedules:
            continue

        # 取今天该药品的所有打卡记录
        existing_logs = db.query(MedicationLog).filter(
            MedicationLog.medication_id == med.id,
            MedicationLog.elder_id == elder_id,
            MedicationLog.scheduled_time >= today_start,
            MedicationLog.scheduled_time < today_end,
            MedicationLog.status == "confirmed",
        ).all()
        checked_schedule_ids = {log.schedule_id for log in existing_logs if log.schedule_id}

        schedule_list = []
        checked_count = 0
        for s in schedules:
            if not s.is_active:
                continue
            checked = s.id in checked_schedule_ids
            if checked:
                checked_count += 1
            else:
                total_pending += 1
            schedule_list.append({
                "schedule_id": s.id,
                "time": s.time_of_day.strftime("%H:%M"),
                "checked": checked,
            })

        total_slots = len(schedule_list)
        if total_slots == 0:
            continue

        items.append({
            "medication_id": med.id,
            "name": med.name,
            "dosage_per_take": med.dosage_per_take,
            "unit": med.unit or "",
            "total_slots": total_slots,
            "checked_slots": checked_count,
            "schedules": schedule_list,
        })

    return {"items": items, "total_pending": total_pending}


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
    _get_elder(db, elder_id)

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

    # 直接通过，无需审核
    create_data["status"] = MedicationStatus.APPROVED
    create_data["created_by"] = "elder"

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
    """修改药品信息"""
    med = _get_medication(db, medication_id, elder_id)

    update_data = body.model_dump(exclude_none=True)
    for k, v in update_data.items():
        setattr(med, k, v)

    # 修改后状态不变，无需重新审核

    db.commit()
    db.refresh(med)
    return _to_medication_response(med)


# ========== 药品提交 & 审核 ==========




@router.delete("/{medication_id}")
def delete_medication(
    medication_id: int,
    db: Session = Depends(get_db),
):
    """删除药品"""
    med = db.query(Medication).filter(Medication.id == medication_id).first()
    if not med:
        raise HTTPException(404, "药品不存在")
    if med.status == MedicationStatus.DISABLED:
        raise HTTPException(400, "已停用的药品不可删除")
    # 删除关联记录
    db.query(MedicationLog).filter(MedicationLog.medication_id == medication_id).delete()
    db.query(MedicationSchedule).filter(MedicationSchedule.medication_id == medication_id).delete()
    db.delete(med)
    db.commit()
    return {"message": "已删除", "id": medication_id}





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

# ========== 打卡 API ==========

@router.post("/{medication_id}/checkin")
def checkin_medication(
    medication_id: int,
    elder_id: int = Query(...),
    body: CheckinRequest = None,
    db: Session = Depends(get_db),
):
    """老人首页一键打卡服药"""
    now = datetime.utcnow()
    med = _get_medication(db, medication_id, elder_id)

    schedules = db.query(MedicationSchedule).filter(
        MedicationSchedule.medication_id == med.id,
        MedicationSchedule.is_active,
    ).order_by(MedicationSchedule.time_of_day).all()

    if not schedules:
        raise HTTPException(400, "该药品无可用定时计划")

    # 确定目标 schedule
    schedule = None
    if body.schedule_index is not None and 0 <= body.schedule_index < len(schedules):
        # 用索引取
        schedule = schedules[body.schedule_index]
    else:
        # 查找当天未确认的时段，取第一个未打卡的
        unchecked = []
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = today_start + timedelta(days=1)
        existing_logs = db.query(MedicationLog).filter(
            MedicationLog.medication_id == med.id,
            MedicationLog.elder_id == elder_id,
            MedicationLog.scheduled_time >= today_start,
            MedicationLog.scheduled_time < today_end,
            MedicationLog.status == "confirmed",
        ).all()
        checked_ids = {log.schedule_id for log in existing_logs if log.schedule_id}
        for s in schedules:
            if s.id not in checked_ids:
                unchecked.append(s)
        if unchecked:
            schedule = unchecked[0]  # 取第一个未打卡的
        else:
            schedule = schedules[0]  # 全打过了，默认第一个

    if not schedule:
        raise HTTPException(400, "无法确定打卡时段")

    # 检查当天是否已重复打卡
    today_date = now.date()
    existing = db.query(MedicationLog).filter(
        MedicationLog.medication_id == med.id,
        MedicationLog.elder_id == elder_id,
        MedicationLog.schedule_id == schedule.id,
        MedicationLog.scheduled_time >= datetime.combine(today_date, dt_time.min),
        MedicationLog.scheduled_time < datetime.combine(today_date, dt_time.max),
        MedicationLog.status == "confirmed",
    ).first()
    if existing:
        raise HTTPException(400, "该时段已打卡，请勿重复打卡")

    # 创建打卡记录
    log = MedicationLog(
        medication_id=med.id,
        elder_id=elder_id,
        schedule_id=schedule.id,
        scheduled_time=datetime.combine(now.date(), schedule.time_of_day),
        confirmed_time=now,
        status="confirmed",
        dosage_taken=schedule.dosage,
        remark="",
    )
    db.add(log)

    # 增加积分 + 更新连续打卡 streak
    points_to_add = 10
    user = db.query(User).filter(User.id == elder_id).first()
    if user.total_points is None:
        user.total_points = 0
    user.total_points += points_to_add

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
    return {"success": True, "points_earned": points_to_add, "streak": user.current_streak}


@router.post("/{medication_id}/checkin/undo")
def undo_checkin_medication(
    medication_id: int,
    elder_id: int = Query(...),
    body: CheckinUndoRequest = None,
    db: Session = Depends(get_db),
):
    """撤销当天的打卡（误打卡回退）"""
    now = datetime.utcnow()
    _get_medication(db, medication_id, elder_id)

    # 找到今天的打卡记录
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)

    log = db.query(MedicationLog).filter(
        MedicationLog.medication_id == medication_id,
        MedicationLog.elder_id == elder_id,
        MedicationLog.schedule_id == body.schedule_id,
        MedicationLog.scheduled_time >= today_start,
        MedicationLog.scheduled_time < today_end,
        MedicationLog.status == "confirmed",
    ).first()

    if not log:
        raise HTTPException(404, "未找到今天的打卡记录")

    # 回退积分
    user = db.query(User).filter(User.id == elder_id).first()
    if user.total_points is None:
        user.total_points = 0
    points_to_deduct = 10
    user.total_points = max(0, user.total_points - points_to_deduct)

    from app.models.point import PointTransaction, TransactionType
    tx = PointTransaction(
        elder_id=elder_id,
        type=TransactionType.REWARD_DOSE,
        amount=-points_to_deduct,
        balance_after=user.total_points,
        description=f"撤销打卡：{log.medication.name}",
    )
    db.add(tx)

    # 标记为 missed 而非真删除
    log.status = "missed"

    # 检查当天是否还有其他已确认打卡，如果完全没有则回退连续打卡
    other_confirmed = db.query(MedicationLog).filter(
        MedicationLog.elder_id == elder_id,
        MedicationLog.scheduled_time >= today_start,
        MedicationLog.scheduled_time < today_end,
        MedicationLog.status == "confirmed",
    ).first()

    if not other_confirmed:
        # 今天没有任何确认打卡了，回退 last_medication_date
        user.last_medication_date = now - timedelta(days=1)
        if user.current_streak > 0:
            user.current_streak -= 1

    db.commit()
    return {"success": True}


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
        "confirmed": sum(1 for log in logs if log.status == "confirmed"),
        "missed": sum(1 for log in logs if log.status == "missed"),
        "items": [
            {
                "id": log.id,
                "medication_name": log.medication.name,
                "scheduled_time": log.scheduled_time.isoformat(),
                "confirmed_time": log.confirmed_time.isoformat() if log.confirmed_time else None,
                "status": log.status,
                "dosage_taken": log.dosage_taken,
            }
            for log in logs
        ],
    }


