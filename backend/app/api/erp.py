"""爸妈宝 — 商城 + ERP API
商品上架 / 采购入库 / 销售订单 / 库存流水 / 预定管理
"""
import json
import logging
import uuid
from datetime import datetime
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from app.models.base import SessionLocal
from app.models.erp import Product, ProductStatus, PurchaseOrder, SalesOrder, StockLog

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/erp", tags=["erp"])


def _gen_no(prefix: str) -> str:
    return f"{prefix}{datetime.now().strftime('%Y%m%d%H%M%S')}{uuid.uuid4().hex[:4].upper()}"


def _log_stock(db, product: Product, change_type: str, qty: int, ref_no: str = "", note: str = ""):
    before = product.stock
    after = before + qty
    product.stock = max(after, 0)
    db.add(StockLog(
        product_id=product.id, product_name=product.name,
        change_type=change_type, quantity=qty,
        before_stock=before, after_stock=product.stock,
        ref_no=ref_no, note=note,
    ))


# ─── 商品管理 ───

class ProductCreate(BaseModel):
    sku: str
    name: str
    model: str = "K1"
    category: str = "wearable"
    sub_category: str = "watch"
    price: float
    original_price: float = 0
    cost_price: float = 0
    stock: int = 0
    min_stock: int = 5
    image_url: str = ""
    description: str = ""
    features: str = "[]"
    is_pre_order: bool = False
    pre_order_days: int = 7


@router.post("/products")
def create_product(req: ProductCreate):
    """创建/上架商品"""
    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.sku == req.sku).first()
        if p:
            p.name = req.name; p.price = req.price; p.original_price = req.original_price
            p.cost_price = req.cost_price; p.image_url = req.image_url
            p.description = req.description; p.features = req.features
            p.is_pre_order = req.is_pre_order; p.pre_order_days = req.pre_order_days
            p.status = ProductStatus.ON_SALE
            db.commit(); db.refresh(p)
            return {"success": True, "message": "商品已更新", "product": p.to_dict()}
        p = Product(
            sku=req.sku, name=req.name, model=req.model,
            category=req.category, sub_category=req.sub_category,
            price=req.price, original_price=req.original_price,
            cost_price=req.cost_price, stock=req.stock, min_stock=req.min_stock,
            image_url=req.image_url, description=req.description,
            features=req.features, is_pre_order=req.is_pre_order,
            pre_order_days=req.pre_order_days, status=ProductStatus.ON_SALE,
        )
        db.add(p); db.commit(); db.refresh(p)
        return {"success": True, "message": "商品已上架", "product": p.to_dict()}
    finally:
        db.close()


@router.get("/products")
def list_products(category: str = "", sub_category: str = "", include_off: bool = False):
    """商品列表（商城默认只显示在售+预售）"""
    db = SessionLocal()
    try:
        q = db.query(Product)
        if not include_off:
            q = q.filter(Product.status.in_([ProductStatus.ON_SALE, ProductStatus.PRE_ORDER]))
        if category:
            q = q.filter(Product.category == category)
        if sub_category:
            q = q.filter(Product.sub_category == sub_category)
        products = q.order_by(Product.id.asc()).all()
        return {"products": [p.to_dict() for p in products]}
    finally:
        db.close()


@router.get("/products/{product_id}")
def get_product(product_id: int):
    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == product_id).first()
        if not p:
            raise HTTPException(404, "商品不存在")
        return p.to_dict()
    finally:
        db.close()


@router.post("/products/{product_id}/status")
def update_product_status(product_id: int, status: str):
    """上下架/预售切换"""
    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == product_id).first()
        if not p:
            raise HTTPException(404, "商品不存在")
        p.status = ProductStatus(status)
        p.is_pre_order = status == "pre_order"
        db.commit()
        return {"success": True, "status": p.status.value}
    finally:
        db.close()


# ─── 采购管理 ───

class PurchaseCreate(BaseModel):
    supplier: str
    items: list[dict]      # [{product_id, quantity, cost_price}]
    note: str = ""


@router.post("/purchase/create")
def create_purchase(req: PurchaseCreate):
    """创建采购单（采购中，不改变库存）"""
    db = SessionLocal()
    try:
        total = 0
        items = []
        for it in req.items[:20]:
            p = db.query(Product).filter(Product.id == it["product_id"]).first()
            if not p:
                continue
            cost = it.get("cost_price", p.cost_price)
            qty = it["quantity"]
            total += cost * qty
            items.append({"product_id": p.id, "product_name": p.name, "sku": p.sku,
                          "quantity": qty, "cost_price": cost})
        if not items:
            raise HTTPException(400, "采购单没有有效商品")
        po = PurchaseOrder(
            po_no=_gen_no("PO"), supplier=req.supplier,
            status="pending", total_cost=total,
            items_json=json.dumps(items, ensure_ascii=False), note=req.note,
        )
        db.add(po); db.commit(); db.refresh(po)
        return {"success": True, "po_no": po.po_no, "total_cost": total, "items": items}
    finally:
        db.close()


@router.post("/purchase/{po_no}/arrive")
def purchase_arrive(po_no: str):
    """采购到货入库（增加库存+流水）"""
    db = SessionLocal()
    try:
        po = db.query(PurchaseOrder).filter(PurchaseOrder.po_no == po_no).first()
        if not po:
            raise HTTPException(404, "采购单不存在")
        if po.status != "pending":
            raise HTTPException(400, "采购单已处理")
        items = json.loads(po.items_json)
        for it in items:
            p = db.query(Product).filter(Product.id == it["product_id"]).first()
            if p:
                _log_stock(db, p, "purchase_in", it["quantity"], ref_no=po_no,
                           note=f"采购入库({po.supplier})")
        po.status = "arrived"
        db.commit()
        return {"success": True, "message": f"已入库{len(items)}种商品"}
    finally:
        db.close()


@router.get("/purchase/list")
def list_purchase():
    db = SessionLocal()
    try:
        pos = db.query(PurchaseOrder).order_by(PurchaseOrder.created_at.desc()).all()
        return {"purchases": [{"po_no": p.po_no, "supplier": p.supplier, "status": p.status,
                               "total_cost": p.total_cost, "items_json": p.items_json,
                               "created_at": p.created_at.isoformat()} for p in pos]}
    finally:
        db.close()


# ─── 销售订单 ───

class OrderCreate(BaseModel):
    product_id: int
    elder_id: int = 1
    buyer_name: str = "用户"
    buyer_phone: str = ""
    buyer_address: str = ""
    quantity: int = 1


@router.post("/order/create")
def create_order(req: OrderCreate):
    """下单（在售=立即扣库存；预售=预定库存）"""
    db = SessionLocal()
    try:
        p = db.query(Product).filter(Product.id == req.product_id).first()
        if not p or p.status not in (ProductStatus.ON_SALE, ProductStatus.PRE_ORDER):
            raise HTTPException(400, "商品不可购买")

        if p.is_pre_order:
            # 预售：占用预定名额
            p.reserved += req.quantity
            status = "pre_order"
            _log_stock(db, p, "reserve", 0, note=f"预定{req.quantity}件")
        else:
            if p.stock < req.quantity:
                raise HTTPException(400, f"库存不足（仅剩{p.stock}件）")
            _log_stock(db, p, "order_out", -req.quantity, note=f"销售{req.quantity}件")
            p.sold += req.quantity
            status = "pending"

        order = SalesOrder(
            order_no=_gen_no("SO"), elder_id=req.elder_id,
            buyer_name=req.buyer_name, buyer_phone=req.buyer_phone,
            buyer_address=req.buyer_address,
            product_id=p.id, product_name=p.name, sku=p.sku,
            price=p.price, quantity=req.quantity,
            total_amount=p.price * req.quantity,
            status=status, is_pre_order=p.is_pre_order,
        )
        db.add(order); db.commit(); db.refresh(order)
        return {"success": True, "order": order.to_dict(),
                "message": "预售预定成功" if p.is_pre_order else "下单成功，待付款"}
    finally:
        db.close()


@router.post("/order/{order_no}/pay")
def pay_order(order_no: str):
    """确认付款（预售订单付款后保留预定）"""
    db = SessionLocal()
    try:
        o = db.query(SalesOrder).filter(SalesOrder.order_no == order_no).first()
        if not o:
            raise HTTPException(404, "订单不存在")
        o.status = "paid" if o.is_pre_order else "paid"
        db.commit()
        return {"success": True, "order_no": order_no, "status": o.status}
    finally:
        db.close()


@router.post("/order/{order_no}/ship")
def ship_order(order_no: str):
    """发货"""
    db = SessionLocal()
    try:
        o = db.query(SalesOrder).filter(SalesOrder.order_no == order_no).first()
        if not o:
            raise HTTPException(404, "订单不存在")
        if o.status == "pre_order":
            # 预售到货发货：预定转库存扣减
            p = db.query(Product).filter(Product.id == o.product_id).first()
            if p:
                p.reserved = max(p.reserved - o.quantity, 0)
                _log_stock(db, p, "order_out", -o.quantity, ref_no=order_no, note="预售发货")
                p.sold += o.quantity
        o.status = "shipped"
        db.commit()
        return {"success": True, "message": "已发货"}
    finally:
        db.close()


@router.post("/order/{order_no}/cancel")
def cancel_order(order_no: str):
    """取消订单（回库）"""
    db = SessionLocal()
    try:
        o = db.query(SalesOrder).filter(SalesOrder.order_no == order_no).first()
        if not o:
            raise HTTPException(404, "订单不存在")
        p = db.query(Product).filter(Product.id == o.product_id).first()
        if p:
            if o.is_pre_order:
                p.reserved = max(p.reserved - o.quantity, 0)
            else:
                _log_stock(db, p, "cancel_in", o.quantity, ref_no=order_no, note="取消回库")
                p.sold = max(p.sold - o.quantity, 0)
        o.status = "cancelled"
        db.commit()
        return {"success": True, "message": "已取消，库存已回"}
    finally:
        db.close()


@router.get("/order/list")
def list_orders(status: str = ""):
    db = SessionLocal()
    try:
        q = db.query(SalesOrder)
        if status:
            q = q.filter(SalesOrder.status == status)
        orders = q.order_by(SalesOrder.created_at.desc()).limit(100).all()
        return {"orders": [o.to_dict() for o in orders]}
    finally:
        db.close()


@router.get("/trace/{code}")
def trace_product(code: str):
    """产品溯源：扫码查询全生命周期
    code 支持：溯源码 trace_code / SKU / 订单号
    """
    db = SessionLocal()
    try:
        # 1. 查产品
        p = db.query(Product).filter(
            (Product.trace_code == code) | (Product.sku == code)
        ).first()
        if not p:
            raise HTTPException(404, "未找到该产品溯源码")

        # 2. 采购记录（该产品所在采购单）
        purchases = db.query(PurchaseOrder).order_by(PurchaseOrder.created_at.asc()).all()
        purchase_records = []
        for po in purchases:
            items = json.loads(po.items_json or "[]")
            for it in items:
                if it.get("product_id") == p.id:
                    purchase_records.append({
                        "po_no": po.po_no, "supplier": po.supplier,
                        "status": po.status, "quantity": it.get("quantity"),
                        "created_at": po.created_at.isoformat(),
                    })

        # 3. 销售订单记录
        orders = db.query(SalesOrder).filter(
            SalesOrder.product_id == p.id
        ).order_by(SalesOrder.created_at.asc()).all()
        order_records = [{
            "order_no": o.order_no, "buyer_name": o.buyer_name,
            "quantity": o.quantity, "status": o.status,
            "created_at": o.created_at.isoformat(),
        } for o in orders]

        # 4. 库存流水
        logs = db.query(StockLog).filter(
            StockLog.product_id == p.id
        ).order_by(StockLog.created_at.asc()).all()
        log_records = [{
            "type": l.change_type, "quantity": l.quantity,
            "before": l.before_stock, "after": l.after_stock,
            "ref_no": l.ref_no, "note": l.note,
            "created_at": l.created_at.isoformat(),
        } for l in logs]

        return {
            "product": p.to_dict(),
            "trace_code": p.trace_code,
            "purchases": purchase_records,
            "orders": order_records,
            "stock_logs": log_records,
        }
    finally:
        db.close()


# ─── 库存 ───

@router.get("/stock")
def list_stock():
    """库存总览（含预警）"""
    db = SessionLocal()
    try:
        products = db.query(Product).all()
        result = []
        for p in products:
            result.append({
                "id": p.id, "name": p.name, "sku": p.sku, "stock": p.stock,
                "reserved": p.reserved, "sold": p.sold, "min_stock": p.min_stock,
                "low_stock": p.stock <= p.min_stock,
                "available": max(p.stock - p.reserved, 0),
            })
        return {"stock": result, "low_count": sum(1 for r in result if r["low_stock"])}
    finally:
        db.close()


@router.get("/stock/logs")
def list_stock_logs(limit: int = 50):
    db = SessionLocal()
    try:
        logs = db.query(StockLog).order_by(StockLog.created_at.desc()).limit(limit).all()
        return {"logs": [{"id": l.id, "product": l.product_name, "type": l.change_type,
                          "quantity": l.quantity, "before": l.before_stock, "after": l.after_stock,
                          "ref_no": l.ref_no, "note": l.note,
                          "created_at": l.created_at.isoformat()} for l in logs]}
    finally:
        db.close()
