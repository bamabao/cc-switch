"""
爸妈宝 API 综合测试脚本

覆盖所有已实现的 API 端点（共 16 个端点）：
  - 健康检查            GET  /api/v1/health
  - 药品管理            9 个端点 (CRUD + 审核 + 确认 + 记录)
  - 审核留痕            1 个端点
  - 积分商城            5 个端点 (概览/流水/商品/兑换/订单)

运行:
    cd backend
    pytest tests/test_api.py -v --tb=short
"""
import pytest
from datetime import date, time
from fastapi.testclient import TestClient


# ======================================================================
# 1. 健康检查
# ======================================================================

class TestHealthCheck:
    def test_health(self, client: TestClient):
        resp = client.get("/api/v1/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert data["app"] == "爸妈宝"


# ======================================================================
# 2. 药品管理
# ======================================================================

class TestMedicationAPI:
    """药品 CRUD + 审核 + 确认 + 记录查询"""

    # ---- 创建药品 ----

    def test_create_oral_medication(self, client: TestClient, elder_user):
        """创建口服药"""
        payload = {
            "category": "oral",
            "name": "阿莫西林胶囊",
            "manufacturer": "白云山制药",
            "unit": "粒",
            "total_quantity": 24.0,
            "oral_form": "capsule",
            "dosage_per_take": 2.0,
            "frequency_per_day": 3,
            "meal_relation": "饭后",
            "notes": "每日3次，每次2粒，饭后服用",
            "schedules": [
                {"time_of_day": "08:00", "dosage": 2.0, "dosage_display": "2粒"},
                {"time_of_day": "13:00", "dosage": 2.0, "dosage_display": "2粒"},
                {"time_of_day": "20:00", "dosage": 2.0, "dosage_display": "2粒"},
            ],
        }
        resp = client.post(f"/api/v1/medications?elder_id={elder_user.id}", json=payload)
        assert resp.status_code == 201, resp.text
        data = resp.json()
        assert data["name"] == "阿莫西林胶囊"
        assert data["category"] == "oral"
        assert data["status"] == "pending"  # 默认待审核
        assert len(data["schedules"]) == 3
        assert data["elder_id"] == elder_user.id

    def test_create_external_medication(self, client: TestClient, elder_user):
        """创建外用药"""
        payload = {
            "category": "external",
            "name": "扶他林软膏",
            "manufacturer": "诺华制药",
            "unit": "支",
            "total_quantity": 1.0,
            "external_form": "ointment",
            "application_site": "膝盖",
            "cycle_info": "每日3次涂抹",
        }
        resp = client.post(f"/api/v1/medications?elder_id={elder_user.id}", json=payload)
        assert resp.status_code == 201, resp.text
        data = resp.json()
        assert data["category"] == "external"
        assert data["external_form"] == "ointment"

    def test_create_injection_medication(self, client: TestClient, elder_user):
        """创建针剂"""
        payload = {
            "category": "injection",
            "name": "胰岛素注射液",
            "manufacturer": "诺和诺德",
            "unit": "IU",
            "total_quantity": 300.0,
            "injection_form": "insulin",
            "injection_site": "腹部",
            "injection_cycle": "每日",
            "shake_before_use": True,
            "hypoglycemia_warning": "注意低血糖症状",
        }
        resp = client.post(f"/api/v1/medications?elder_id={elder_user.id}", json=payload)
        assert resp.status_code == 201, resp.text
        data = resp.json()
        assert data["category"] == "injection"
        assert data["injection_form"] == "insulin"

    def test_create_supplement_medication(self, client: TestClient, elder_user):
        """创建滋补辅药"""
        payload = {
            "category": "supplement",
            "name": "钙尔奇D片",
            "manufacturer": "赫力昂",
            "unit": "片",
            "total_quantity": 60.0,
            "supplement_type": "保健调理",
        }
        resp = client.post(f"/api/v1/medications?elder_id={elder_user.id}", json=payload)
        assert resp.status_code == 201, resp.text
        data = resp.json()
        assert data["category"] == "supplement"
        assert data["supplement_type"] == "保健调理"

    def test_create_duplicate_name_fails(self, client: TestClient, elder_user):
        """同名药品（非禁用状态）应返回 400"""
        payload = {"category": "oral", "name": "测试重复药", "oral_form": "tablet"}
        resp1 = client.post(f"/api/v1/medications?elder_id={elder_user.id}", json=payload)
        assert resp1.status_code == 201, resp1.text
        resp2 = client.post(f"/api/v1/medications?elder_id={elder_user.id}", json=payload)
        assert resp2.status_code == 400, resp2.text
        assert "已存在" in resp2.text

    # ---- 查询药品 ----

    def test_list_medications(self, client: TestClient, elder_user, medication):
        """获取药品列表"""
        resp = client.get(f"/api/v1/medications?elder_id={elder_user.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert "items" in data
        assert len(data["items"]) >= 1

    def test_list_medications_by_category(self, client: TestClient, elder_user, medication):
        """按分类筛选药品"""
        resp = client.get(f"/api/v1/medications?elder_id={elder_user.id}&category=oral")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["items"]) >= 1

    def test_list_medications_by_status(self, client: TestClient, elder_user, medication, pending_medication):
        """按状态筛选药品"""
        resp = client.get(f"/api/v1/medications?elder_id={elder_user.id}&status=approved")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["items"]) >= 1
        for item in data["items"]:
            assert item["status"] == "approved"

    def test_list_pending_review(self, client: TestClient, elder_user, pending_medication):
        """获取待审核药品"""
        resp = client.get(f"/api/v1/medications/pending?elder_id={elder_user.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] >= 1
        for item in data["items"]:
            assert item["status"] == "pending"

    def test_get_medication_detail(self, client: TestClient, elder_user, medication):
        """获取单个药品详情"""
        resp = client.get(f"/api/v1/medications/{medication.id}?elder_id={elder_user.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == medication.id
        assert data["name"] == medication.name

    # ---- 修改药品 ----

    def test_update_medication(self, client: TestClient, elder_user, medication):
        """修改药品信息"""
        resp = client.put(
            f"/api/v1/medications/{medication.id}?elder_id={elder_user.id}",
            json={"notes": "更新后的备注信息", "dosage_per_take": 1.0},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "更新后的备注信息" in data["notes"]

    def test_update_approved_medication_resets_to_pending(self, client: TestClient, elder_user, medication):
        """已审核通过再修改，应重置为待审核"""
        resp = client.put(
            f"/api/v1/medications/{medication.id}?elder_id={elder_user.id}",
            json={"notes": "修改后需要重新审核"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "pending"

    # ---- 提审 & 审核 ----

    def test_submit_pending_medication(self, client: TestClient, elder_user, pending_medication):
        """提交待审核药品"""
        resp = client.post(
            f"/api/v1/medications/{pending_medication.id}/submit?elder_id={elder_user.id}"
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["status"] == "pending"

    def test_submit_approved_medication_fails(self, client: TestClient, elder_user, medication):
        """已审核通过的药品提交应返回400"""
        resp = client.post(
            f"/api/v1/medications/{medication.id}/submit?elder_id={elder_user.id}"
        )
        assert resp.status_code == 400
        assert "无需重复提交" in resp.text

    def test_submit_and_audit_flow(self, client: TestClient, elder_user, child_user):
        """创药 → 提交 → 审核通过的完整流程"""
        create_resp = client.post(
            f"/api/v1/medications?elder_id={elder_user.id}",
            json={"category": "oral", "name": "可审核通过药", "oral_form": "tablet"},
        )
        assert create_resp.status_code == 201
        med_id = create_resp.json()["id"]

        submit_resp = client.post(f"/api/v1/medications/{med_id}/submit?elder_id={elder_user.id}")
        assert submit_resp.status_code == 200
        assert submit_resp.json()["status"] == "pending"

        audit_resp = client.post(
            f"/api/v1/medications/{med_id}/audit?child_id={child_user.id}",
            json={"action": "approve"},
        )
        assert audit_resp.status_code == 200
        assert audit_resp.json()["status"] == "approved"

    def test_audit_approve(self, client: TestClient, child_user, pending_medication):
        """子女审核通过"""
        resp = client.post(
            f"/api/v1/medications/{pending_medication.id}/audit?child_id={child_user.id}",
            json={"action": "approve"},
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["status"] == "approved"

    def test_audit_reject(self, client: TestClient, child_user, elder_user):
        """子女审核驳回"""
        create_resp = client.post(
            f"/api/v1/medications?elder_id={elder_user.id}",
            json={"category": "oral", "name": "会被驳回的药", "oral_form": "tablet"},
        )
        assert create_resp.status_code == 201
        med_id = create_resp.json()["id"]

        reject_resp = client.post(
            f"/api/v1/medications/{med_id}/audit?child_id={child_user.id}",
            json={"action": "reject"},
        )
        assert reject_resp.status_code == 200, reject_resp.text
        assert reject_resp.json()["status"] == "rejected"

    def test_audit_reject_with_reason(self, client: TestClient, child_user, elder_user):
        """驳回并写明原因"""
        create_resp = client.post(
            f"/api/v1/medications?elder_id={elder_user.id}",
            json={"category": "oral", "name": "需驳回药", "oral_form": "tablet"},
        )
        assert create_resp.status_code == 201
        med_id = create_resp.json()["id"]

        reject_resp = client.post(
            f"/api/v1/medications/{med_id}/audit?child_id={child_user.id}",
            json={"action": "reject", "reject_reason": "剂量过大，请减少"},
        )
        assert reject_resp.status_code == 200, reject_resp.text
        assert reject_resp.json()["status"] == "rejected"

    # ---- 用药确认 ----

    def test_confirm_medication(self, client: TestClient, elder_user, medication, medication_schedule):
        """确认用药"""
        resp = client.post(
            f"/api/v1/medications/confirm?elder_id={elder_user.id}",
            json={
                "medication_id": medication.id,
                "schedule_id": medication_schedule.id,
                "dosage_taken": 2.0,
                "remark": "按时服用",
            },
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["points_earned"] == 10

    def test_confirm_with_invalid_schedule(self, client: TestClient, elder_user, medication):
        """无效的 schedule_id 应返回 404"""
        resp = client.post(
            f"/api/v1/medications/confirm?elder_id={elder_user.id}",
            json={"medication_id": medication.id, "schedule_id": 99999, "dosage_taken": 2.0},
        )
        assert resp.status_code == 404

    # ---- 记录查询 ----

    def test_medication_logs_history(self, client: TestClient, elder_user, medication, medication_schedule):
        """查询用药历史记录"""
        # 先确认一次用药
        client.post(
            f"/api/v1/medications/confirm?elder_id={elder_user.id}",
            json={"medication_id": medication.id, "schedule_id": medication_schedule.id},
        )
        resp = client.get(f"/api/v1/medications/logs/history?elder_id={elder_user.id}&days=30")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] >= 1
        assert data["confirmed"] >= 1

    def test_medication_logs_filter_by_medication(self, client: TestClient, elder_user, medication, medication_schedule):
        """按药品筛选用药记录"""
        client.post(
            f"/api/v1/medications/confirm?elder_id={elder_user.id}",
            json={"medication_id": medication.id, "schedule_id": medication_schedule.id},
        )
        resp = client.get(
            f"/api/v1/medications/logs/history?elder_id={elder_user.id}&medication_id={medication.id}"
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] >= 1

    # ---- 错误场景 ----

    def test_get_nonexistent_elder(self, client: TestClient):
        """不存在的老人应返回 404"""
        resp = client.get("/api/v1/medications?elder_id=99999")
        assert resp.status_code == 404

    def test_get_nonexistent_medication(self, client: TestClient, elder_user):
        """不存在的药品应返回 404"""
        resp = client.get(f"/api/v1/medications/99999?elder_id={elder_user.id}")
        assert resp.status_code == 404


# ======================================================================
# 3. 审核日志
# ======================================================================

class TestAuditAPI:
    """审核留痕 API"""

    def test_audit_history(self, client: TestClient, elder_user, child_user, pending_medication):
        """获取审核历史"""
        client.post(
            f"/api/v1/medications/{pending_medication.id}/audit?child_id={child_user.id}",
            json={"action": "approve"},
        )
        resp = client.get(f"/api/v1/audit/history?elder_id={elder_user.id}&days=30")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] >= 1
        actions = [item["action"] for item in data["items"]]
        assert "approve" in actions

    def test_audit_history_filter_by_medication(self, client: TestClient, elder_user, child_user, pending_medication):
        """按药品筛选审核记录"""
        client.post(
            f"/api/v1/medications/{pending_medication.id}/audit?child_id={child_user.id}",
            json={"action": "approve"},
        )
        resp = client.get(
            f"/api/v1/audit/history?elder_id={elder_user.id}&medication_id={pending_medication.id}"
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] >= 1

    def test_audit_has_reject_reason(self, client: TestClient, elder_user, child_user):
        """驳回记录应包含驳回原因"""
        create_resp = client.post(
            f"/api/v1/medications?elder_id={elder_user.id}",
            json={"category": "oral", "name": "需驳回药2号", "oral_form": "tablet"},
        )
        med_id = create_resp.json()["id"]
        client.post(
            f"/api/v1/medications/{med_id}/audit?child_id={child_user.id}",
            json={"action": "reject", "reject_reason": "药品名称不规范"},
        )
        resp = client.get(f"/api/v1/audit/history?elder_id={elder_user.id}")
        data = resp.json()
        reject_records = [r for r in data["items"] if r["action"] == "reject"]
        assert len(reject_records) >= 1
        assert reject_records[0]["reject_reason"] == "药品名称不规范"


# ======================================================================
# 4. 积分系统
# ======================================================================

class TestPointsAPI:
    """积分概览 + 流水 + 商城 + 兑换 + 订单"""

    def test_point_profile(self, client: TestClient, elder_user):
        """获取积分概览"""
        resp = client.get(f"/api/v1/points/profile?elder_id={elder_user.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert "total_points" in data
        assert "current_streak" in data
        assert "longest_streak" in data
        assert "today_earned" in data

    def test_nonexistent_point_profile(self, client: TestClient):
        """不存在的用户积分概览应返回 404"""
        resp = client.get("/api/v1/points/profile?elder_id=99999")
        assert resp.status_code == 404

    def test_point_transactions(self, client: TestClient, elder_user):
        """积分流水（空时也应返回正确结构）"""
        resp = client.get(f"/api/v1/points/transactions?elder_id={elder_user.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert "total" in data and "items" in data

    def test_point_transactions_after_redeem(self, client: TestClient, elder_user, point_product):
        """兑换后产生积分流水记录"""
        client.post(
            f"/api/v1/points/redeem?elder_id={elder_user.id}&product_id={point_product.id}"
        )
        resp = client.get(f"/api/v1/points/transactions?elder_id={elder_user.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] >= 1

    def test_list_products(self, client: TestClient, point_product):
        """商品列表"""
        resp = client.get("/api/v1/points/products")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["items"]) >= 1

    def test_list_products_by_category(self, client: TestClient, point_product):
        """按分类筛选商品"""
        resp = client.get("/api/v1/points/products?category=health")
        assert resp.status_code == 200
        data = resp.json()
        for item in data["items"]:
            assert item["category"] == "health"

    def test_redeem_product_success(self, client: TestClient, elder_user, point_product):
        """积分兑换成功"""
        initial_points = elder_user.total_points
        resp = client.post(
            f"/api/v1/points/redeem?elder_id={elder_user.id}&product_id={point_product.id}"
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["message"] == "兑换成功"
        assert data["order_id"] > 0
        assert data["points_remaining"] == initial_points - point_product.price_points

    def test_redeem_insufficient_points(self, client: TestClient, elder_user, db):
        """积分不足应返回 400"""
        from app.models.point import PointProduct as PP
        expensive = PP(name="奢侈品", price_points=999999, stock=5)
        db.add(expensive)
        db.commit()
        db.refresh(expensive)

        resp = client.post(
            f"/api/v1/points/redeem?elder_id={elder_user.id}&product_id={expensive.id}"
        )
        assert resp.status_code == 400
        assert "积分不足" in resp.text

    def test_redeem_out_of_stock(self, client: TestClient, elder_user, db):
        """库存不足应返回 400"""
        from app.models.point import PointProduct as PP
        out_of_stock = PP(name="热销品", price_points=50, stock=0)
        db.add(out_of_stock)
        db.commit()
        db.refresh(out_of_stock)

        resp = client.post(
            f"/api/v1/points/redeem?elder_id={elder_user.id}&product_id={out_of_stock.id}"
        )
        assert resp.status_code == 400
        assert "库存不足" in resp.text

    def test_redeem_nonexistent_product(self, client: TestClient, elder_user):
        """不存在的商品应返回 404"""
        resp = client.post(
            f"/api/v1/points/redeem?elder_id={elder_user.id}&product_id=99999"
        )
        assert resp.status_code == 404

    def test_list_orders(self, client: TestClient, elder_user, point_product):
        """兑换订单列表"""
        client.post(
            f"/api/v1/points/redeem?elder_id={elder_user.id}&product_id={point_product.id}"
        )
        resp = client.get(f"/api/v1/points/orders?elder_id={elder_user.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["items"]) >= 1
        assert data["items"][0]["product_name"] == point_product.name


# ======================================================================
# 5. 集成场景
# ======================================================================

class TestIntegration:
    """完整业务流程集成测试"""

    def test_full_medication_lifecycle(self, client: TestClient, elder_user, child_user):
        """完整用药生命周期：创建 → 提交 → 审核 → 确认 → 记录"""
        # 1. 创建
        create_resp = client.post(
            f"/api/v1/medications?elder_id={elder_user.id}",
            json={
                "category": "oral",
                "name": "集成测试降压药",
                "manufacturer": "测试厂",
                "oral_form": "tablet",
                "dosage_per_take": 0.5,
                "frequency_per_day": 1,
                "meal_relation": "早饭前",
                "unit": "片",
                "total_quantity": 30.0,
                "schedules": [{"time_of_day": "07:00", "dosage": 0.5, "dosage_display": "半片"}],
            },
        )
        assert create_resp.status_code == 201
        med_id = create_resp.json()["id"]

        # 2. 审核通过
        audit_resp = client.post(
            f"/api/v1/medications/{med_id}/audit?child_id={child_user.id}",
            json={"action": "approve"},
        )
        assert audit_resp.status_code == 200
        assert audit_resp.json()["status"] == "approved"

        # 3. 获取详情
        detail_resp = client.get(f"/api/v1/medications/{med_id}?elder_id={elder_user.id}")
        assert detail_resp.json()["status"] == "approved"

        # 4. 确认用药
        schedule_id = detail_resp.json()["schedules"][0]["id"]
        confirm_resp = client.post(
            f"/api/v1/medications/confirm?elder_id={elder_user.id}",
            json={"medication_id": med_id, "schedule_id": schedule_id, "dosage_taken": 0.5},
        )
        assert confirm_resp.status_code == 200
        assert confirm_resp.json()["points_earned"] == 10

        # 5. 查询日志
        log_resp = client.get(f"/api/v1/medications/logs/history?elder_id={elder_user.id}&days=7")
        assert log_resp.status_code == 200
        assert log_resp.json()["total"] >= 1

        # 6. 查询审核日志
        audit_log_resp = client.get(f"/api/v1/audit/history?elder_id={elder_user.id}")
        assert audit_log_resp.status_code == 200
        assert audit_log_resp.json()["total"] >= 2  # create + approve

    def test_full_points_lifecycle(self, client: TestClient, elder_user, db):
        """完整积分生命周期：概览 → 商品 → 兑换 → 订单 → 流水"""
        # 1. 概览
        profile_resp = client.get(f"/api/v1/points/profile?elder_id={elder_user.id}")
        assert profile_resp.status_code == 200
        initial_points = profile_resp.json()["total_points"]

        # 2. 通过 db fixture 创建商品
        from app.models.point import PointProduct as PP
        product = PP(name="维生素礼盒", price_points=100, stock=5, category="health")
        db.add(product)
        db.commit()
        db.refresh(product)

        # 3. 兑换
        redeem_resp = client.post(
            f"/api/v1/points/redeem?elder_id={elder_user.id}&product_id={product.id}"
        )
        assert redeem_resp.status_code == 200, redeem_resp.text
        assert redeem_resp.json()["points_remaining"] == initial_points - 100

        # 4. 订单
        orders_resp = client.get(f"/api/v1/points/orders?elder_id={elder_user.id}")
        assert len(orders_resp.json()["items"]) == 1
        assert orders_resp.json()["items"][0]["points_spent"] == 100

        # 5. 流水
        tx_resp = client.get(f"/api/v1/points/transactions?elder_id={elder_user.id}")
        assert tx_resp.json()["total"] >= 1
        tx_types = [t["type"] for t in tx_resp.json()["items"]]
        assert "redeem" in tx_types
