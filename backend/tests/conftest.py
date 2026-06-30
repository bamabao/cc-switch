"""
Pytest 共享配置
- 使用独立 SQLite 文件数据库
- 预置老人 + 子女用户
- 预置积分商城商品
"""
import os
import sys
from pathlib import Path
from datetime import time as dtime

# 确保可找到 app 包
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.models.base import Base, get_db
from app.models.user import User, UserRole, FamilyBinding
from app.models.medication import (
    Medication, MedicationSchedule, MedicationLog,
    DrugCategory, MedicationStatus, OralForm,
)
from app.models.audit import AuditRecord, AuditAction
from app.models.point import (
    PointTransaction, PointProduct, PointOrder,
    TransactionType, OrderStatus,
)
from app.main import app

# 独立测试数据库
TEST_DB_URL = "sqlite:///./test_bamabao.db"
engine = create_engine(TEST_DB_URL, echo=False)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(scope="session", autouse=True)
def setup_database():
    """迁移前清空旧测试库，创建表"""
    db_path = Path(__file__).resolve().parents[1] / "test_bamabao.db"
    if db_path.exists():
        try:
            db_path.unlink()
        except PermissionError:
            pass
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture(autouse=True)
def override_dependency(setup_database):
    """所有测试用测试数据库"""
    app.dependency_overrides[get_db] = override_get_db
    yield
    app.dependency_overrides.clear()


@pytest.fixture(autouse=True)
def cleanup_db():
    """每个测试后清理数据"""
    yield
    db = TestingSessionLocal()
    try:
        for table in reversed(Base.metadata.sorted_tables):
            db.execute(table.delete())
        db.commit()
    finally:
        db.close()


@pytest.fixture
def db():
    """获取测试数据库会话"""
    database = TestingSessionLocal()
    try:
        yield database
    finally:
        database.close()


# ========== 预置用户 ==========

@pytest.fixture
def elder_user(db) -> User:
    user = User(
        openid="elder_wx_001",
        nickname="张大爷",
        role=UserRole.ELDER,
        voice_preference="mandarin",
        font_scale=200,
        total_points=1000,
        current_streak=5,
        longest_streak=15,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def child_user(db) -> User:
    user = User(
        openid="child_wx_001",
        nickname="张小美",
        role=UserRole.CHILD,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def family_binding(db, elder_user, child_user) -> FamilyBinding:
    binding = FamilyBinding(
        elder_id=elder_user.id,
        child_id=child_user.id,
        relation_label="女儿",
    )
    db.add(binding)
    db.commit()
    db.refresh(binding)
    return binding


# ========== 预置药品 ==========

@pytest.fixture
def medication(db, elder_user) -> Medication:
    med = Medication(
        elder_id=elder_user.id,
        category=DrugCategory.ORAL,
        name="阿莫西林胶囊",
        manufacturer="白云山制药",
        unit="粒",
        total_quantity=24.0,
        status=MedicationStatus.APPROVED,
        oral_form=OralForm.CAPSULE,
        dosage_per_take=2.0,
        frequency_per_day=3,
        meal_relation="饭后",
        created_by="elder",
        notes="每日3次，每次2粒，饭后服用",
    )
    db.add(med)
    db.commit()
    db.refresh(med)
    return med


@pytest.fixture
def medication_schedule(db, medication) -> MedicationSchedule:
    schedule = MedicationSchedule(
        medication_id=medication.id,
        time_of_day=dtime(8, 0),  # ✅ 使用 time 对象而非字符串
        dosage=2.0,
        dosage_display="2粒",
        weekday_mask=127,
    )
    db.add(schedule)
    db.commit()
    db.refresh(schedule)
    return schedule


@pytest.fixture
def pending_medication(db, elder_user) -> Medication:
    med = Medication(
        elder_id=elder_user.id,
        category=DrugCategory.ORAL,
        name="维生素C片",
        manufacturer="汤臣倍健",
        unit="片",
        total_quantity=60.0,
        status=MedicationStatus.PENDING,
        oral_form=OralForm.TABLET,
        dosage_per_take=1.0,
        frequency_per_day=1,
        meal_relation="饭后",
        created_by="elder",
    )
    db.add(med)
    db.commit()
    db.refresh(med)
    return med


# ========== 预置积分商品 ==========

@pytest.fixture
def point_product(db) -> PointProduct:
    product = PointProduct(
        name="按摩仪",
        category="health",
        description="颈部按摩放松",
        price_points=200,
        stock=10,
    )
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@pytest.fixture
def client():
    return TestClient(app)
