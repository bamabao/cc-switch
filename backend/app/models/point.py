from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text, JSON, Enum as SAEnum, Boolean
from sqlalchemy.orm import relationship
from .base import Base
import enum


class TransactionType(str, enum.Enum):
    REWARD_DOSE = "reward_dose"          # 按时用药
    REWARD_STREAK_7 = "reward_streak_7"  # 连续7天
    REWARD_STREAK_30 = "reward_streak_30"  # 连续30天
    REWARD_FILE = "reward_file"          # 档案录入
    REWARD_CLEANUP = "reward_cleanup"    # 清理过期药
    REDEEM = "redeem"                    # 兑换消费
    ADMIN_ADJUST = "admin_adjust"        # 管理调整


class OrderStatus(str, enum.Enum):
    PENDING = "pending"        # 待发货
    SHIPPED = "shipped"        # 已发货
    DELIVERED = "delivered"    # 已签收
    CANCELLED = "cancelled"    # 已取消


class PointTransaction(Base):
    """积分流水"""
    __tablename__ = "point_transactions"

    id = Column(Integer, primary_key=True, index=True)
    elder_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    type = Column(SAEnum(TransactionType), nullable=False)
    amount = Column(Integer, nullable=False)  # 正=增加，负=消费
    balance_after = Column(Integer, nullable=False)
    description = Column(String(256), default="")
    reference_id = Column(String(64), nullable=True)  # 关联ID（用药记录、兑换订单）
    created_at = Column(DateTime, default=datetime.utcnow)


class PointProduct(Base):
    """积分商品"""
    __tablename__ = "point_products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(128), nullable=False)
    category = Column(String(32), default="daily")  # daily | health | entertainment
    description = Column(Text, default="")
    price_points = Column(Integer, nullable=False)
    image_url = Column(String(256), default="")
    stock = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class PointOrder(Base):
    """兑换订单"""
    __tablename__ = "point_orders"

    id = Column(Integer, primary_key=True, index=True)
    elder_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    product_id = Column(Integer, ForeignKey("point_products.id"), nullable=False)
    points_spent = Column(Integer, nullable=False)
    status = Column(SAEnum(OrderStatus), default=OrderStatus.PENDING)
    tracking_number = Column(String(128), default="")
    logistics_info = Column(Text, default="")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    product = relationship("PointProduct", lazy="joined")
