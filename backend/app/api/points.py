from typing import Optional, List
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from app.models.base import get_db
from app.models.point import PointTransaction, PointProduct, PointOrder, TransactionType, OrderStatus
from app.models.user import User

router = APIRouter(prefix="/api/v1/points", tags=["积分商城"])


# ========== 积分查询 ==========

@router.get("/profile")
def get_point_profile(
    elder_id: int = Query(...),
    db: Session = Depends(get_db),
):
    """积分概览"""
    user = db.query(User).filter(User.id == elder_id).first()
    if not user:
        raise HTTPException(404, "用户不存在")

    return {
        "total_points": user.total_points,
        "current_streak": user.current_streak,
        "longest_streak": user.longest_streak,
        "today_earned": _get_today_earned(db, elder_id),
    }


def _get_today_earned(db: Session, elder_id: int) -> int:
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    total = (
        db.query(PointTransaction)
        .filter(
            PointTransaction.elder_id == elder_id,
            PointTransaction.amount > 0,
            PointTransaction.created_at >= today_start,
        )
        .with_entities(PointTransaction.amount)
        .all()
    )
    return sum(t.amount for t in total)


@router.get("/transactions")
def get_point_transactions(
    elder_id: int = Query(...),
    limit: int = Query(50),
    offset: int = Query(0),
    db: Session = Depends(get_db),
):
    """积分流水"""
    q = (
        db.query(PointTransaction)
        .filter(PointTransaction.elder_id == elder_id)
        .order_by(PointTransaction.created_at.desc())
    )
    total = q.count()
    items = q.offset(offset).limit(limit).all()
    return {
        "total": total,
        "items": [
            {
                "id": t.id,
                "type": t.type.value,
                "amount": t.amount,
                "balance_after": t.balance_after,
                "description": t.description,
                "created_at": t.created_at.isoformat(),
            }
            for t in items
        ],
    }


# ========== 积分商城 ==========

@router.get("/products")
def list_products(
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    """商品列表"""
    q = db.query(PointProduct).filter(PointProduct.is_active == True)
    if category:
        q = q.filter(PointProduct.category == category)
    products = q.all()
    return {
        "items": [
            {
                "id": p.id,
                "name": p.name,
                "category": p.category,
                "description": p.description,
                "price_points": p.price_points,
                "image_url": p.image_url,
                "stock": p.stock,
            }
            for p in products
        ]
    }


@router.post("/redeem")
def redeem_product(
    elder_id: int = Query(...),
    product_id: int = Query(...),
    db: Session = Depends(get_db),
):
    """积分兑换"""
    user = db.query(User).filter(User.id == elder_id).first()
    if not user:
        raise HTTPException(404, "用户不存在")

    product = db.query(PointProduct).filter(PointProduct.id == product_id, PointProduct.is_active).first()
    if not product:
        raise HTTPException(404, "商品不存在")
    if product.stock <= 0:
        raise HTTPException(400, "商品库存不足")
    if user.total_points < product.price_points:
        raise HTTPException(400, f"积分不足，需要{product.price_points}，当前{user.total_points}")

    # 扣积分
    user.total_points -= product.price_points
    product.stock -= 1

    # 流水
    tx = PointTransaction(
        elder_id=elder_id,
        type=TransactionType.REDEEM,
        amount=-product.price_points,
        balance_after=user.total_points,
        description=f"兑换：{product.name}",
    )
    db.add(tx)

    # 订单
    order = PointOrder(
        elder_id=elder_id,
        product_id=product.id,
        points_spent=product.price_points,
        status=OrderStatus.PENDING,
    )
    db.add(order)
    db.commit()
    db.refresh(order)

    return {
        "message": "兑换成功",
        "order_id": order.id,
        "points_remaining": user.total_points,
    }


@router.get("/orders")
def list_orders(
    elder_id: int = Query(...),
    db: Session = Depends(get_db),
):
    """兑换订单列表"""
    orders = (
        db.query(PointOrder)
        .filter(PointOrder.elder_id == elder_id)
        .order_by(PointOrder.created_at.desc())
        .all()
    )
    return {
        "items": [
            {
                "id": o.id,
                "product_name": o.product.name if o.product else "",
                "points_spent": o.points_spent,
                "status": o.status.value,
                "tracking_number": o.tracking_number,
                "logistics_info": o.logistics_info,
                "created_at": o.created_at.isoformat(),
            }
            for o in orders
        ]
    }
