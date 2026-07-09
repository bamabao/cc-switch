"""
爸妈宝 — 数据库种子数据
为所有功能页面提供真实展示数据
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

from datetime import date, time, datetime, timedelta
from app.models.base import SessionLocal
from app.models import (
    User, FamilyBinding, Medication, MedicationSchedule,
    MedicationLog, PointProduct, PointTransaction, PointOrder
)

def seed():
    db = SessionLocal()
    try:
        # 清空旧数据
        for table in [PointOrder, PointTransaction, PointProduct,
                      MedicationLog, MedicationSchedule, Medication,
                      FamilyBinding, User]:
            db.query(table).delete()
        db.commit()

        now = datetime.utcnow()
        today = now.date()

        # ── 1. 用户 ──
        elder = User(
            phone="13800138000",
            nickname="张奶奶",
            role="elder",
            avatar_url="",
            voice_preference="mandarin",
            font_scale=200,
            is_active=True,
            total_points=1280,
        )
        child1 = User(
            phone="13900139000",
            nickname="小李（儿子）",
            role="child",
            avatar_url="",
            voice_preference="mandarin",
            font_scale=200,
            is_active=True,
        )
        db.add_all([elder, child1])
        db.flush()

        # ── 2. 家庭绑定 ──
        binding = FamilyBinding(
            child_id=child1.id,
            elder_id=elder.id,
            relation_label="儿子",
            is_active=True,
        )
        db.add(binding)

        # ── 3. 药品 ──
        med1 = Medication(
            elder_id=elder.id,
            name="苯磺酸氨氯地平片",
            category="oral",
            oral_form="tablet",
            manufacturer="辉瑞制药",
            dosage_per_take=1.0,
            unit="片",
            frequency_per_day=1,
            total_quantity=30,
            meal_relation="早餐后",
            dietary_restrictions="忌葡萄柚",
            side_effects="偶有头痛、水肿",
            notes="降压药，不可自行停药",
            status="APPROVED",
            created_at=now - timedelta(days=7),
        )
        med2 = Medication(
            elder_id=elder.id,
            name="阿托伐他汀钙片",
            category="oral",
            oral_form="tablet",
            manufacturer="辉瑞制药",
            dosage_per_take=1.0,
            unit="片",
            frequency_per_day=1,
            total_quantity=30,
            meal_relation="睡前",
            dietary_restrictions="忌酒精",
            side_effects="偶有肌肉酸痛",
            notes="降脂药",
            status="APPROVED",
            created_at=now - timedelta(days=5),
        )
        med3 = Medication(
            elder_id=elder.id,
            name="阿莫西林胶囊",
            category="oral",
            oral_form="capsule",
            manufacturer="石药集团",
            dosage_per_take=2.0,
            unit="粒",
            frequency_per_day=3,
            total_quantity=36,
            meal_relation="餐后",
            dietary_restrictions="忌酒",
            side_effects="偶有腹泻",
            notes="抗生素，需按疗程服用",
            status="APPROVED",
            created_at=now - timedelta(hours=2),
        )
        db.add_all([med1, med2, med3])
        db.flush()

        # ── 4. 服药时间表 ──
        sched1 = MedicationSchedule(
            medication_id=med1.id,
            time_of_day=time(8, 0),
            weekday_mask=127,
            dosage=1.0,
            dosage_display="1片",
            is_active=True,
        )
        sched2 = MedicationSchedule(
            medication_id=med2.id,
            time_of_day=time(21, 0),
            weekday_mask=127,
            dosage=1.0,
            dosage_display="1片",
            is_active=True,
        )
        db.add_all([sched1, sched2])
        db.flush()

        # ── 5. 用药日志（过去7天） ──
        for day_offset in range(7, -1, -1):
            day = today - timedelta(days=day_offset)
            for sched, med in [(sched1, med1), (sched2, med2)]:
                h, m = sched.time_of_day.hour, sched.time_of_day.minute
                scheduled_at = datetime.combine(day, time(h, m))
                is_future = scheduled_at > now
                is_old = day_offset >= 2
                is_recent_but_past = day_offset <= 1 and scheduled_at < now

                if is_future:
                    log_status = "PENDING"
                    confirmed = None
                    dosage = None
                elif is_old or (day_offset == 1 and h < now.hour):
                    log_status = "CONFIRMED"
                    confirmed = scheduled_at + timedelta(minutes=5)
                    dosage = med.dosage_per_take
                else:
                    log_status = "MISSED"
                    confirmed = None
                    dosage = None

                reminder1 = scheduled_at - timedelta(minutes=5) if scheduled_at < now else None
                reminder2 = scheduled_at + timedelta(minutes=15) if scheduled_at + timedelta(minutes=15) < now else None
                alert_child = log_status == "MISSED" and day_offset <= 1

                log = MedicationLog(
                    medication_id=med.id,
                    elder_id=elder.id,
                    schedule_id=sched.id,
                    scheduled_time=scheduled_at,
                    confirmed_time=confirmed,
                    status=log_status,
                    dosage_taken=dosage,
                    remark="",
                    reminder_sent_1=reminder1,
                    reminder_sent_2=reminder2,
                    alert_sent_to_child=alert_child,
                )
                db.add(log)

        # ── 6. 积分商品 ──
        products = [
            PointProduct(name="10元话费券", price_points=500, stock=100, description="移动/联通/电信通用"),
            PointProduct(name="20元话费券", price_points=900, stock=50, description="移动/联通/电信通用"),
            PointProduct(name="维生素C泡腾片", price_points=300, stock=30, description="增强免疫力"),
            PointProduct(name="电子血压计", price_points=2000, stock=10, description="家中常备"),
            PointProduct(name="爸妈宝定制保温杯", price_points=1500, stock=20, description="316不锈钢内胆"),
        ]
        db.add_all(products)

        # ── 7. 积分记录 ──
        tx = PointTransaction(
            elder_id=elder.id,
            amount=1280,
            type="reward_streak_7",
            balance_after=1280,
            description="连续打卡7天奖励",
            created_at=now - timedelta(hours=3),
        )
        db.add(tx)

        db.commit()
        print("[OK] 种子数据写入成功！")
        print(f"  用户: {elder.nickname}(elder) + {child1.nickname}(child)")
        print(f"  药品: {med1.name}, {med2.name}, {med3.name}(全部已批准)")
        print(f"  日志: 过去7天")
        print(f"  积分: 1280分 + {len(products)}种商品")
        print(f"  老人手机号: 13800138000 (验证码: 123456)")
        print("  [注意] 审核流程已移除，所有药品添加直接可用")
    except Exception as e:
        db.rollback()
        print(f"[ERROR] 写入失败: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    seed()
