"""爸妈宝 — 商城商品 + ERP模型（采购/库存/销售/预定）"""
import enum
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Float, Text, Boolean, Enum as SAEnum, ForeignKey
from .base import Base


class ProductStatus(str, enum.Enum):
    DRAFT = "draft"          # 草稿
    ON_SALE = "on_sale"      # 在售
    OFF_SALE = "off_sale"    # 下架
    PRE_ORDER = "pre_order"  # 预售


class Product(Base):
    """商城商品"""
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    sku = Column(String(64), unique=True, index=True)     # 如 BMBW-K1-BLACK
    name = Column(String(128), nullable=False)
    model = Column(String(32), default="")                # 型号 K1
    category = Column(String(32), default="wearable")     # wearable/accessory/supplement
    sub_category = Column(String(32), default="watch")    # watch/ring/band
    price = Column(Float, default=0)                      # 售价
    original_price = Column(Float, default=0)             # 划线价
    cost_price = Column(Float, default=0)                 # 成本价
    stock = Column(Integer, default=0)                    # 当前库存
    reserved = Column(Integer, default=0)                 # 已预定数量
    sold = Column(Integer, default=0)                     # 已售数量
    min_stock = Column(Integer, default=5)                # 库存预警线
    image_url = Column(String(256), default="")
    description = Column(Text, default="")
    features = Column(Text, default="[]")                 # 卖点JSON数组
    specs = Column(Text, default="{}")                    # 规格JSON
    trace_code = Column(String(64), unique=True, index=True)  # 产品溯源码（一物一码）
    batch_no = Column(String(64), default="")             # 生产批次号
    manufacturer = Column(String(128), default="")        # 生产厂家
    made_date = Column(String(32), default="")            # 生产日期
    status = Column(SAEnum(ProductStatus), default=ProductStatus.ON_SALE)
    is_pre_order = Column(Boolean, default=False)         # 是否预售
    pre_order_days = Column(Integer, default=7)           # 预售发货天数
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id, "sku": self.sku, "name": self.name, "model": self.model,
            "category": self.category, "sub_category": self.sub_category,
            "price": self.price, "original_price": self.original_price,
            "cost_price": self.cost_price,
            "stock": self.stock, "reserved": self.reserved, "sold": self.sold,
            "min_stock": self.min_stock, "image_url": self.image_url,
            "description": self.description, "features": self.features,
            "trace_code": self.trace_code, "batch_no": self.batch_no,
            "manufacturer": self.manufacturer, "made_date": self.made_date,
            "status": self.status.value, "is_pre_order": self.is_pre_order,
            "pre_order_days": self.pre_order_days,
        }


class PurchaseOrder(Base):
    """采购单"""
    __tablename__ = "purchase_orders"

    id = Column(Integer, primary_key=True, index=True)
    po_no = Column(String(64), unique=True, index=True)
    supplier = Column(String(128), default="")
    status = Column(String(16), default="pending")    # pending采购中/arrived已入库/cancelled取消
    total_cost = Column(Float, default=0)
    items_json = Column(Text, default="[]")
    note = Column(Text, default="")
    created_at = Column(DateTime, default=datetime.utcnow)


class SalesOrder(Base):
    """销售订单"""
    __tablename__ = "sales_orders"

    id = Column(Integer, primary_key=True, index=True)
    order_no = Column(String(64), unique=True, index=True)
    elder_id = Column(Integer, default=0)
    buyer_name = Column(String(64), default="")
    buyer_phone = Column(String(32), default="")
    buyer_address = Column(String(256), default="")
    product_id = Column(Integer, ForeignKey("products.id"), index=True)
    product_name = Column(String(128), default="")
    sku = Column(String(64), default="")
    price = Column(Float, default=0)
    quantity = Column(Integer, default=1)
    total_amount = Column(Float, default=0)
    status = Column(String(16), default="pending")    # pending待付款/paid已付款/pre_order预售中/shipped已发货/completed已完成/cancelled已取消
    is_pre_order = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id, "order_no": self.order_no, "elder_id": self.elder_id,
            "buyer_name": self.buyer_name, "buyer_phone": self.buyer_phone,
            "buyer_address": self.buyer_address, "product_id": self.product_id,
            "product_name": self.product_name, "sku": self.sku,
            "price": self.price, "quantity": self.quantity,
            "total_amount": self.total_amount, "status": self.status,
            "is_pre_order": self.is_pre_order,
            "created_at": self.created_at.isoformat(),
        }


class StockLog(Base):
    """库存流水"""
    __tablename__ = "stock_logs"

    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id"), index=True)
    product_name = Column(String(128), default="")
    change_type = Column(String(16), default="")   # purchase_in采购入库/order_out销售出库/cancel_in取消回库/reserve预定/reserve_cancel
    quantity = Column(Integer, default=0)          # 正数入/负数出
    before_stock = Column(Integer, default=0)
    after_stock = Column(Integer, default=0)
    ref_no = Column(String(64), default="")        # 关联单号
    note = Column(String(256), default="")
    created_at = Column(DateTime, default=datetime.utcnow)
