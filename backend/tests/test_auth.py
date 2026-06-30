"""
用户认证体系测试
"""
import pytest
from fastapi.testclient import TestClient


class TestAuthAPI:
    """认证 + 用户管理"""

    def test_phone_login_new_user(self, client: TestClient):
        """手机号登录 — 新用户自动注册"""
        resp = client.post(
            "/api/v1/auth/login/phone",
            json={"phone": "13800138000", "code": "123456", "role": "elder"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["token_type"] == "bearer"
        assert data["role"] == "elder"
        assert data["user_id"] > 0
        assert len(data["access_token"]) > 10

    def test_phone_login_wrong_code(self, client: TestClient):
        """验证码错误"""
        resp = client.post(
            "/api/v1/auth/login/phone",
            json={"phone": "13800138001", "code": "000000", "role": "elder"},
        )
        assert resp.status_code == 400
        assert "验证码错误" in resp.text

    def test_phone_login_existing_user(self, client: TestClient, elder_user, db):
        """手机号登录 — 已有用户"""
        elder_user.phone = "13900139000"
        db.commit()
        db.refresh(elder_user)
        resp = client.post(
            "/api/v1/auth/login/phone",
            json={"phone": "13900139000", "code": "123456", "role": "elder"},
        )
        assert resp.status_code == 200
        assert resp.json()["user_id"] == elder_user.id

    def test_wechat_login_new_user(self, client: TestClient):
        """微信登录 — 新用户"""
        resp = client.post(
            "/api/v1/auth/login/wechat",
            json={"code": "test_code_123", "role": "child"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["role"] == "child"
        assert data["user_id"] > 0

    def test_wechat_login_existing_user(self, client: TestClient):
        """微信登录 — 已有用户"""
        # 第一次登录
        resp1 = client.post(
            "/api/v1/auth/login/wechat",
            json={"code": "reuse_code", "role": "child"},
        )
        user_id_1 = resp1.json()["user_id"]

        # 同 code 再登录（同一 openid）
        resp2 = client.post(
            "/api/v1/auth/login/wechat",
            json={"code": "reuse_code", "role": "child"},
        )
        assert resp2.json()["user_id"] == user_id_1

    def test_send_sms(self, client: TestClient):
        """发送验证码"""
        resp = client.post("/api/v1/auth/send-sms?phone=13800138000")
        assert resp.status_code == 200
        assert "已发送" in resp.json()["message"]

    def test_bind_family(self, client: TestClient, elder_user, child_user, db):
        """子女绑定老人"""
        elder_user.phone = "13700137000"
        db.commit()

        resp = client.post(
            "/api/v1/auth/bind-family?child_id=" + str(child_user.id),
            json={"elder_phone": "13700137000"},
        )
        assert resp.status_code == 200
        assert resp.json()["elder_id"] == elder_user.id

    def test_bind_family_not_found(self, client: TestClient, child_user):
        """绑定不存在的老人"""
        resp = client.post(
            "/api/v1/auth/bind-family?child_id=" + str(child_user.id),
            json={"elder_phone": "19999999999"},
        )
        assert resp.status_code == 404

    def test_bind_family_duplicate(self, client: TestClient, elder_user, child_user, db):
        """重复绑定"""
        elder_user.phone = "13600136000"
        db.commit()
        # 第一次
        client.post(
            "/api/v1/auth/bind-family?child_id=" + str(child_user.id),
            json={"elder_phone": "13600136000"},
        )
        # 第二次
        resp = client.post(
            "/api/v1/auth/bind-family?child_id=" + str(child_user.id),
            json={"elder_phone": "13600136000"},
        )
        assert resp.status_code == 400
        assert "已绑定" in resp.text

    def test_get_my_info_elder(self, client: TestClient, elder_user, child_user, db):
        """获取老人用户信息（含家庭成员）"""
        from app.models.user import FamilyBinding
        elder_user.phone = "13800138000"
        db.commit()
        db.refresh(elder_user)
        binding = FamilyBinding(elder_id=elder_user.id, child_id=child_user.id, relation_label="女儿")
        db.add(binding)
        db.commit()

        login_resp = client.post(
            "/api/v1/auth/login/phone",
            json={"phone": "13800138000", "code": "123456", "role": "elder"},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]
        resp = client.get(f"/api/v1/auth/me?token={token}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["role"] == "elder"
        assert len(data["family_members"]) >= 1
        assert data["family_members"][0]["role"] == "child"

    def test_update_profile(self, client: TestClient, elder_user, db):
        """更新用户资料"""
        elder_user.phone = "13500135000"
        db.commit()
        login_resp = client.post(
            "/api/v1/auth/login/phone",
            json={"phone": "13500135000", "code": "123456", "role": "elder"},
        )
        token = login_resp.json()["access_token"]
        resp = client.put(
            f"/api/v1/auth/profile?token={token}&nickname=张大爷改&voice_preference=cantonese&font_scale=250",
        )
        assert resp.status_code == 200
        assert "更新成功" in resp.json()["message"]

    def test_invalid_token(self, client: TestClient):
        """无效 token"""
        resp = client.get("/api/v1/auth/me?token=invalid_token_123")
        assert resp.status_code == 401

    def test_missing_token(self, client: TestClient):
        """缺少 token"""
        resp = client.get("/api/v1/auth/me?token=")
        assert resp.status_code == 401
