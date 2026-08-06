"""爸妈宝运营 — 数据统计看板 API（大屏+手机管理端）"""
import json
import logging
import hashlib
import hmac
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import func, text
from app.models.base import SessionLocal
from app.models.doctor import Doctor, DoctorStatus, Order, ConsultationMessage, DoctorPatient, SubscriptionPlan
from app.models.user import User, UserRole
from app.models.medication import MedicationLog, Medication

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/admin", tags=["admin"])

# ─── 管理后台访问控制 ───
# 管理密码（生产环境需改环境变量 ADMIN_PASSWORD）
_ADMIN_PASSWORD = "bmb2026admin"


class PassVerify(BaseModel):
    password: str


def _require_admin(request: Request):
    """校验管理端访问：X-Admin-Token 头"""
    token = request.headers.get("X-Admin-Token", "")
    if not token:
        raise HTTPException(401, "未授权访问")
    expected = hashlib.sha256(_ADMIN_PASSWORD.encode()).hexdigest()
    if not hmac.compare_digest(token, expected):
        raise HTTPException(401, "未授权访问")


@router.post("/verify-pass")
def verify_pass(body: PassVerify):
    """验证管理密码（给Web登录页用）"""
    if hmac.compare_digest(body.password, _ADMIN_PASSWORD):
        token = hashlib.sha256(_ADMIN_PASSWORD.encode()).hexdigest()
        return {"ok": True, "token": token}
    return {"ok": False}


@router.get("/dashboard")
def dashboard(request: Request):
    """运营大屏核心指标（需管理密码）"""
    _require_admin(request)
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

        # 用户统计
        total_patients = db.query(User).filter(User.role == UserRole.ELDER).count()
        today_new_patients = db.query(User).filter(
            User.role == UserRole.ELDER,
            User.created_at >= today_start
        ).count()

        # 医生统计
        total_doctors = db.query(Doctor).count()
        approved_doctors = db.query(Doctor).filter(Doctor.status == DoctorStatus.APPROVED).count()
        pending_doctors = db.query(Doctor).filter(Doctor.status == DoctorStatus.PENDING).count()

        # 收入统计
        total_revenue = db.query(func.coalesce(func.sum(Order.amount), 0)).filter(
            Order.status == "paid"
        ).scalar()
        today_revenue = db.query(func.coalesce(func.sum(Order.amount), 0)).filter(
            Order.status == "paid",
            Order.paid_at >= today_start
        ).scalar()
        month_revenue = db.query(func.coalesce(func.sum(Order.amount), 0)).filter(
            Order.status == "paid",
            Order.paid_at >= today_start.replace(day=1)
        ).scalar()

        # 消息统计
        today_messages = db.query(ConsultationMessage).filter(
            ConsultationMessage.created_at >= today_start
        ).count()
        unread_messages = db.query(ConsultationMessage).filter(
            ConsultationMessage.is_read == False
        ).count()

        # 打卡统计
        today_checkins = db.query(MedicationLog).filter(
            MedicationLog.confirmed_time >= today_start
        ).count()

        # 医患绑定
        total_bindings = db.query(DoctorPatient).filter(DoctorPatient.is_active == True).count()

        # 紧急消息
        today_emergency = db.query(ConsultationMessage).filter(
            ConsultationMessage.is_emergency == True,
            ConsultationMessage.created_at >= today_start
        ).count()

        # ─── ERP商城统计（与驾驶舱打通） ───
        from app.models.erp import Product, SalesOrder
        total_products = db.query(Product).count()
        total_stock = db.query(func.coalesce(func.sum(Product.stock), 0)).scalar()
        total_reserved = db.query(func.coalesce(func.sum(Product.reserved), 0)).scalar()
        total_sold = db.query(func.coalesce(func.sum(Product.sold), 0)).scalar()
        low_stock_products = db.query(Product).filter(Product.stock <= Product.min_stock).count()
        # ERP销售额（已付款/发货/完成/预售）
        erp_revenue = db.query(func.coalesce(func.sum(SalesOrder.total_amount), 0)).filter(
            SalesOrder.status.in_(["paid", "shipped", "completed", "pre_order"])
        ).scalar()
        today_sales = db.query(SalesOrder).filter(
            SalesOrder.created_at >= today_start
        ).count()

        return {
            "timestamp": now.isoformat(),
            "users": {
                "total_patients": total_patients,
                "today_new_patients": today_new_patients,
                "today_checkins": today_checkins,
            },
            "doctors": {
                "total": total_doctors,
                "approved": approved_doctors,
                "pending": pending_doctors,
                "assistants": db.query(Doctor).filter(Doctor.status == DoctorStatus.APPROVED).count(),
            },
            "revenue": {
                "total": float(total_revenue or 0),
                "today": float(today_revenue or 0),
                "month": float(month_revenue or 0),
            },
            "messages": {
                "today": today_messages,
                "unread": unread_messages,
                "emergency_today": today_emergency,
            },
            "bindings": total_bindings,
            # ERP商城
            "erp": {
                "products": total_products,
                "stock": int(total_stock or 0),
                "reserved": int(total_reserved or 0),
                "sold": int(total_sold or 0),
                "low_stock": low_stock_products,
                "revenue": float(erp_revenue or 0),
                "today_sales": today_sales,
            },
        }
    finally:
        db.close()


@router.get("/trend")
def trend(request: Request, days: int = 30):
    """30天增长趋势（需管理密码）"""
    _require_admin(request)
    db = SessionLocal()
    try:
        result = []
        now = datetime.utcnow()
        for i in range(days - 1, -1, -1):
            day = now - timedelta(days=i)
            day_start = day.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start + timedelta(days=1)

            new_patients = db.query(User).filter(
                User.role == UserRole.ELDER,
                User.created_at >= day_start,
                User.created_at < day_end
            ).count()
            new_doctors = db.query(Doctor).filter(
                Doctor.created_at >= day_start,
                Doctor.created_at < day_end
            ).count()
            revenue = db.query(func.coalesce(func.sum(Order.amount), 0)).filter(
                Order.status == "paid",
                Order.paid_at >= day_start,
                Order.paid_at < day_end
            ).scalar()
            checkins = db.query(MedicationLog).filter(
                MedicationLog.confirmed_time >= day_start,
                MedicationLog.confirmed_time < day_end
            ).count()

            result.append({
                "date": day.strftime("%m-%d"),
                "new_patients": new_patients,
                "new_doctors": new_doctors,
                "revenue": float(revenue or 0),
                "checkins": checkins,
            })
        return {"trend": result}
    finally:
        db.close()


@router.get("/plan-distribution")
def plan_distribution(request: Request):
    """套餐分布（需管理密码）"""
    _require_admin(request)
    db = SessionLocal()
    try:
        result = []
        for plan in SubscriptionPlan:
            count = db.query(Doctor).filter(Doctor.plan == plan).count()
            if count > 0:
                result.append({"plan": plan.value, "count": count})
        return {"distribution": result}
    finally:
        db.close()


@router.get("/doctor-ranking")
def doctor_ranking(limit: int = 10):
    """医生活跃度排行"""
    db = SessionLocal()
    try:
        doctors = db.query(Doctor).filter(Doctor.status == DoctorStatus.APPROVED).all()
        ranking = []
        for d in doctors:
            patient_count = db.query(DoctorPatient).filter(
                DoctorPatient.doctor_id == d.id,
                DoctorPatient.is_active == True
            ).count()
            msg_count = db.query(ConsultationMessage).filter(
                ConsultationMessage.doctor_id == d.id,
                ConsultationMessage.created_at >= datetime.utcnow() - timedelta(days=7)
            ).count()
            ranking.append({
                "doctor_id": d.id,
                "name": d.real_name,
                "hospital": d.hospital,
                "patients": patient_count,
                "messages_7d": msg_count,
                "score": patient_count * 2 + msg_count,
            })
        ranking.sort(key=lambda x: x["score"], reverse=True)
        return {"ranking": ranking[:limit]}
    finally:
        db.close()


@router.get("/alerts")
def alerts(request: Request):
    """实时预警（需管理密码）"""
    _require_admin(request)
    db = SessionLocal()
    try:
        alerts_list = []

        # 待审核医生
        pending = db.query(Doctor).filter(Doctor.status == DoctorStatus.PENDING).all()
        for d in pending:
            alerts_list.append({
                "level": "warning",
                "type": "doctor_audit",
                "message": f"新医生待审核：{d.real_name}（{d.hospital}）",
                "doctor_id": d.id,
            })

        # 近24小时紧急消息
        emergency = db.query(ConsultationMessage).filter(
            ConsultationMessage.is_emergency == True,
            ConsultationMessage.created_at >= datetime.utcnow() - timedelta(hours=24)
        ).all()
        for m in emergency:
            alerts_list.append({
                "level": "danger",
                "type": "emergency",
                "message": f"紧急消息：{m.content[:50]}",
                "message_id": m.id,
            })

        # 即将到期订阅
        expiring = db.query(Doctor).filter(
            Doctor.plan_expire_at != None,
            Doctor.plan_expire_at <= datetime.utcnow() + timedelta(days=7)
        ).all()
        for d in expiring:
            alerts_list.append({
                "level": "info",
                "type": "plan_expiring",
                "message": f"{d.real_name} 的套餐将于 {d.plan_expire_at.strftime('%m-%d')} 到期",
                "doctor_id": d.id,
            })

        alerts_list.sort(key=lambda x: {"danger": 0, "warning": 1, "info": 2}[x["level"]])
        return {"alerts": alerts_list[:20]}
    finally:
        db.close()


@router.get("/orders")
def orders(request: Request, limit: int = 50, status: str = ""):
    """订单列表（需管理密码）"""
    _require_admin(request)
    db = SessionLocal()
    try:
        q = db.query(Order).order_by(Order.created_at.desc())
        if status:
            q = q.filter(Order.status == status)
        orders = q.limit(limit).all()

        result = []
        for o in orders:
            doctor = db.query(Doctor).filter(Doctor.id == o.doctor_id).first()
            result.append({
                "order_no": o.order_no,
                "doctor_name": doctor.real_name if doctor else "?",
                "plan": o.plan.value,
                "amount": o.amount,
                "months": o.months,
                "status": o.status,
                "pay_method": o.pay_method,
                "paid_at": o.paid_at.isoformat() if o.paid_at else None,
                "created_at": o.created_at.isoformat(),
            })
        return {"orders": result}
    finally:
        db.close()
