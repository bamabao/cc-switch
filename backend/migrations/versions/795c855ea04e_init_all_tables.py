"""init_all_tables — 创建所有核心表

Revision ID: 795c855ea04e
Revises:
Create Date: 2026-06-26 00:45:31.305542

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "795c855ea04e"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---------- users ----------
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("openid", sa.String(64), nullable=True),
        sa.Column("phone", sa.String(20), nullable=True),
        sa.Column("nickname", sa.String(64), nullable=True, server_default=""),
        sa.Column("avatar_url", sa.String(256), nullable=True, server_default=""),
        sa.Column(
            "role",
            sa.Enum("elder", "child", name="userrole"),
            nullable=False,
        ),
        sa.Column("is_active", sa.Boolean(), nullable=True, server_default="1"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.Column("voice_preference", sa.String(32), nullable=True, server_default="mandarin"),
        sa.Column("font_scale", sa.Integer(), nullable=True, server_default="200"),
        sa.Column("current_streak", sa.Integer(), nullable=True, server_default="0"),
        sa.Column("longest_streak", sa.Integer(), nullable=True, server_default="0"),
        sa.Column("last_medication_date", sa.DateTime(), nullable=True),
        sa.Column("total_points", sa.Integer(), nullable=True, server_default="0"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_id"), "users", ["id"], unique=False)
    op.create_index(op.f("ix_users_openid"), "users", ["openid"], unique=True)
    op.create_index(op.f("ix_users_phone"), "users", ["phone"], unique=True)

    # ---------- family_bindings ----------
    op.create_table(
        "family_bindings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("elder_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("child_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("relation_label", sa.String(32), nullable=True, server_default=""),
        sa.Column("is_active", sa.Boolean(), nullable=True, server_default="1"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_family_bindings_id"), "family_bindings", ["id"], unique=False)

    # ---------- medications ----------
    op.create_table(
        "medications",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("elder_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column(
            "category",
            sa.Enum("oral", "external", "injection", "supplement", name="drugcategory"),
            nullable=False,
        ),
        sa.Column("name", sa.String(128), nullable=False),
        sa.Column("manufacturer", sa.String(128), nullable=True, server_default=""),
        sa.Column("expiry_date", sa.Date(), nullable=True),
        sa.Column("total_quantity", sa.Float(), nullable=True),
        sa.Column("unit", sa.String(16), nullable=True, server_default=""),
        sa.Column("notes", sa.Text(), nullable=True, server_default=""),
        sa.Column("photo_urls", sa.JSON(), nullable=True),
        sa.Column(
            "status",
            sa.Enum("pending", "approved", "rejected", "disabled", name="medicationstatus"),
            nullable=True,
        ),
        sa.Column("created_by", sa.String(32), nullable=True, server_default="elder"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        # 内服
        sa.Column("oral_form", sa.Enum("tablet", "capsule", "granule", "oral_liquid", "decoction", name="oralform"), nullable=True),
        sa.Column("dosage_per_take", sa.Float(), nullable=True),
        sa.Column("frequency_per_day", sa.Integer(), nullable=True),
        sa.Column("meal_relation", sa.String(16), nullable=True),
        sa.Column("dietary_restrictions", sa.Text(), nullable=True, server_default=""),
        sa.Column("side_effects", sa.Text(), nullable=True, server_default=""),
        # 外用
        sa.Column("external_form", sa.Enum("ointment", "spray", "drops", "patch", "iodophor", "lotion", name="externalform"), nullable=True),
        sa.Column("application_site", sa.String(128), nullable=True, server_default=""),
        sa.Column("cycle_info", sa.String(128), nullable=True, server_default=""),
        sa.Column("skin_allergy_warning", sa.String(256), nullable=True, server_default=""),
        sa.Column("storage_requirement", sa.String(128), nullable=True, server_default=""),
        # 针剂
        sa.Column("injection_form", sa.Enum("insulin", "subcutaneous", "long_acting", "infusion", name="injectionform"), nullable=True),
        sa.Column("injection_site", sa.String(128), nullable=True, server_default=""),
        sa.Column("injection_cycle", sa.String(32), nullable=True, server_default=""),
        sa.Column("shake_before_use", sa.Boolean(), nullable=True, server_default="0"),
        sa.Column("hypoglycemia_warning", sa.String(256), nullable=True, server_default=""),
        sa.Column("allergy_warning", sa.String(256), nullable=True, server_default=""),
        # 滋补
        sa.Column("supplement_type", sa.String(32), nullable=True, server_default=""),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_medications_id"), "medications", ["id"], unique=False)

    # ---------- medication_schedules ----------
    op.create_table(
        "medication_schedules",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("medication_id", sa.Integer(), sa.ForeignKey("medications.id"), nullable=False, index=True),
        sa.Column("time_of_day", sa.Time(), nullable=False),
        sa.Column("weekday_mask", sa.Integer(), nullable=True, server_default="127"),
        sa.Column("dosage", sa.Float(), nullable=False),
        sa.Column("dosage_display", sa.String(32), nullable=True, server_default=""),
        sa.Column("is_active", sa.Boolean(), nullable=True, server_default="1"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_medication_schedules_id"), "medication_schedules", ["id"], unique=False)

    # ---------- medication_logs ----------
    op.create_table(
        "medication_logs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("medication_id", sa.Integer(), sa.ForeignKey("medications.id"), nullable=False, index=True),
        sa.Column("elder_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("schedule_id", sa.Integer(), sa.ForeignKey("medication_schedules.id"), nullable=True),
        sa.Column("scheduled_time", sa.DateTime(), nullable=False),
        sa.Column("confirmed_time", sa.DateTime(), nullable=True),
        sa.Column("status", sa.String(16), nullable=True, server_default="confirmed"),
        sa.Column("dosage_taken", sa.Float(), nullable=True),
        sa.Column("remark", sa.String(256), nullable=True, server_default=""),
        sa.Column("reminder_sent_1", sa.DateTime(), nullable=True),
        sa.Column("reminder_sent_2", sa.DateTime(), nullable=True),
        sa.Column("alert_sent_to_child", sa.Boolean(), nullable=True, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_medication_logs_id"), "medication_logs", ["id"], unique=False)

    # ---------- audit_records ----------
    op.create_table(
        "audit_records",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("medication_id", sa.Integer(), sa.ForeignKey("medications.id"), nullable=False, index=True),
        sa.Column("actor_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "action",
            sa.Enum("create", "update", "submit", "approve", "reject", name="auditaction"),
            nullable=False,
        ),
        sa.Column("detail", sa.Text(), nullable=True, server_default=""),
        sa.Column("reject_reason", sa.Text(), nullable=True, server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_audit_records_id"), "audit_records", ["id"], unique=False)

    # ---------- point_transactions ----------
    op.create_table(
        "point_transactions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("elder_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column(
            "type",
            sa.Enum(
                "reward_dose", "reward_streak_7", "reward_streak_30",
                "reward_file", "reward_cleanup", "redeem", "admin_adjust",
                name="transactiontype",
            ),
            nullable=False,
        ),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("balance_after", sa.Integer(), nullable=False),
        sa.Column("description", sa.String(256), nullable=True, server_default=""),
        sa.Column("reference_id", sa.String(64), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_point_transactions_id"), "point_transactions", ["id"], unique=False)

    # ---------- point_products ----------
    op.create_table(
        "point_products",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(128), nullable=False),
        sa.Column("category", sa.String(32), nullable=True, server_default="daily"),
        sa.Column("description", sa.Text(), nullable=True, server_default=""),
        sa.Column("price_points", sa.Integer(), nullable=False),
        sa.Column("image_url", sa.String(256), nullable=True, server_default=""),
        sa.Column("stock", sa.Integer(), nullable=True, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=True, server_default="1"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_point_products_id"), "point_products", ["id"], unique=False)

    # ---------- point_orders ----------
    op.create_table(
        "point_orders",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("elder_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("product_id", sa.Integer(), sa.ForeignKey("point_products.id"), nullable=False),
        sa.Column("points_spent", sa.Integer(), nullable=False),
        sa.Column(
            "status",
            sa.Enum("pending", "shipped", "delivered", "cancelled", name="orderstatus"),
            nullable=True,
        ),
        sa.Column("tracking_number", sa.String(128), nullable=True, server_default=""),
        sa.Column("logistics_info", sa.Text(), nullable=True, server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_point_orders_id"), "point_orders", ["id"], unique=False)


def downgrade() -> None:
    op.drop_table("point_orders")
    op.drop_table("point_products")
    op.drop_table("point_transactions")
    op.drop_table("audit_records")
    op.drop_table("medication_logs")
    op.drop_table("medication_schedules")
    op.drop_table("medications")
    op.drop_table("family_bindings")
    op.drop_table("users")

    # Drop ENUM types (SQLite doesn't enforce them, but clean up anyway)
    op.execute("DROP TYPE IF EXISTS userrole")
    op.execute("DROP TYPE IF EXISTS drugcategory")
    op.execute("DROP TYPE IF EXISTS medicationstatus")
    op.execute("DROP TYPE IF EXISTS oralform")
    op.execute("DROP TYPE IF EXISTS externalform")
    op.execute("DROP TYPE IF EXISTS injectionform")
    op.execute("DROP TYPE IF EXISTS auditaction")
    op.execute("DROP TYPE IF EXISTS transactiontype")
    op.execute("DROP TYPE IF EXISTS orderstatus")
