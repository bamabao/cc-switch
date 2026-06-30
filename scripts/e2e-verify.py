#!/usr/bin/env python3
"""爸妈宝 端到端完整性验证脚本"""
import sys, json, time, os, hashlib
import httpx

BASE = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1].startswith("http") else "http://localhost:8000"
client = httpx.Client(base_url=BASE, timeout=10)

P, F, E = 0, 0, []
pad = lambda: print(f"{'='*50}")

def ok(name, cond, detail=""):
    global P, F
    if cond:
        P += 1
        print(f"  [OK] {name}")
    else:
        F += 1
        print(f"  [FAIL] {name}: {detail}")
        E.append(f"{name}: {detail}")

def sec(title):
    pad()
    print(f"  {title}")
    pad()

uid = hashlib.md5(str(time.time()).encode()).hexdigest()[:6]
print(f"\n=== 爸妈宝 E2E Verify ===\n  Base: {BASE}\n  Run: {uid}\n")
start = time.time()

try:
    # ===== 1. Health =====
    sec("1. Health")
    d = client.get("/api/v1/health").json()
    ok("status ok", d.get("status") == "ok")

    # ===== 2. Auth =====
    sec("2. Auth")
    r = client.post("/api/v1/auth/login/phone", json={"phone":"13800138000","code":"123456","role":"elder"})
    d = r.json()
    ok("elder login", r.status_code == 200 and "access_token" in d)
    et, ei = d.get("access_token",""), d.get("user_id", 0)
    ok("elder token", bool(et))
    ok("elder role", d.get("role") == "elder")

    r = client.post("/api/v1/auth/login/wechat", json={"code":"child01","role":"child"})
    d = r.json()
    ok("child login", r.status_code == 200 and "access_token" in d)
    ct, ci = d.get("access_token",""), d.get("user_id", 0)
    ok("child token", bool(ct))
    ok("child role", d.get("role") == "child")

    r = client.post("/api/v1/auth/login/phone", json={"phone":"13800138001","code":"000000","role":"elder"})
    ok("wrong code 400", r.status_code == 400)

    r = client.post("/api/v1/auth/send-sms?phone=13800138000")
    ok("sms ok", r.status_code == 200 and r.json().get("code") == "123456")

    r = client.post(f"/api/v1/auth/bind-family?child_id={ci}", json={"elder_phone":"13800138000"})
    ok("bind family", r.status_code in (200, 400))

    r = client.get(f"/api/v1/auth/me?token={et}")
    ok("get me", r.status_code == 200)

    # ===== 3. Medication CRUD =====
    sec("3. Medication CRUD")
    body = {
        "category":"oral", "name":f"降压药_{uid}", "oral_form":"tablet",
        "dosage_per_take":1, "frequency_per_day":2, "meal_relation":"饭后",
        "schedules":[
            {"time_of_day":"08:00", "dosage":1.0, "dosage_display":"1片"},
            {"time_of_day":"20:00", "dosage":1.0, "dosage_display":"1片"}
        ]
    }
    r = client.post(f"/api/v1/medications?elder_id={ei}", json=body)
    d = r.json()
    ok("create oral med", r.status_code == 201)
    ok("status pending", d.get("status") == "pending")
    mi = d.get("id", 0)
    ok("has id", mi > 0)
    ok("has 2 schedules", len(d.get("schedules", [])) == 2)
    si = d["schedules"][0]["id"]

    for cat in [("external", {"external_form":"ointment","application_site":"膝盖"}),
                ("injection", {"injection_form":"insulin","shake_before_use":True}),
                ("supplement", {"supplement_type":"保健调理"})]:
        r = client.post(f"/api/v1/medications?elder_id={ei}",
                       json={"category":cat[0], "name":f"test_{cat[0]}_{uid}", **cat[1]})
        ok(f"create {cat[0]} med", r.status_code in (201, 400))

    r = client.post(f"/api/v1/medications?elder_id={ei}",
                   json={"category":"oral", "name":f"降压药_{uid}", "oral_form":"tablet"})
    ok("duplicate name 400", r.status_code == 400)

    r = client.get(f"/api/v1/medications?elder_id={ei}")
    ok("list meds", r.status_code == 200 and len(r.json().get("items",[])) >= 1)

    r = client.get(f"/api/v1/medications?elder_id={ei}&category=oral")
    ok("filter by category", all(m["category"]=="oral" for m in r.json().get("items",[])))

    r = client.get(f"/api/v1/medications/pending?elder_id={ei}")
    ok("pending list", r.json().get("total",0) >= 1)

    r = client.get(f"/api/v1/medications/{mi}?elder_id={ei}")
    ok("get detail", r.json().get("name") == f"降压药_{uid}")

    r = client.put(f"/api/v1/medications/{mi}?elder_id={ei}", json={"notes":"已调整"})
    ok("update med", r.status_code == 200)
    ok("reset to pending", r.json().get("status") == "pending")

    # ===== 4. Audit Flow =====
    sec("4. Audit Flow")
    r = client.post(f"/api/v1/medications/{mi}/submit?elder_id={ei}")
    ok("submit audit", r.status_code == 200)

    r = client.post(f"/api/v1/medications/{mi}/audit?child_id={ci}", json={"action":"approve"})
    ok("approve", r.status_code == 200 and r.json().get("status") == "approved")

    r = client.post(f"/api/v1/medications/{mi}/submit?elder_id={ei}")
    ok("re-submit approved 400", r.status_code == 400)

    r = client.post(f"/api/v1/medications?elder_id={ei}",
                   json={"category":"oral", "name":f"驳回药_{uid}", "oral_form":"tablet"})
    ri = r.json().get("id", 0)
    r = client.post(f"/api/v1/medications/{ri}/audit?child_id={ci}", json={"action":"reject","reject_reason":"剂量过大"})
    ok("reject with reason", r.status_code == 200 and r.json().get("status") == "rejected")

    # ===== 5. Confirm + Logs =====
    sec("5. Confirm + Logs")
    r = client.post(f"/api/v1/medications/confirm?elder_id={ei}",
                   json={"medication_id":mi, "schedule_id":si, "dosage_taken":1.0})
    ok("confirm med", r.status_code == 200 and r.json().get("points_earned") == 10)

    r = client.post(f"/api/v1/medications/confirm?elder_id={ei}",
                   json={"medication_id":mi, "schedule_id":99999})
    ok("invalid schedule 404", r.status_code == 404)

    r = client.get(f"/api/v1/medications/logs/history?elder_id={ei}&days=30")
    d = r.json()
    ok("logs have records", d.get("total",0) >= 1 and d.get("confirmed",0) >= 1)

    # ===== 6. Audit Log =====
    sec("6. Audit Logs")
    r = client.get(f"/api/v1/audit/history?elder_id={ei}&days=30")
    d = r.json()
    ok("audit log records", d.get("total",0) >= 1)
    ok("contains approve", sum(1 for a in d.get("items",[]) if a["action"]=="approve") >= 1)

    # ===== 7. Alerts =====
    sec("7. Alerts")
    r = client.get(f"/api/v1/medications/alerts?elder_id={ei}")
    ok("alerts endpoint", r.status_code == 200)
    ok("alerts has items", "items" in r.json())

    # ===== 8. Points =====
    sec("8. Points")
    r = client.get(f"/api/v1/points/profile?elder_id={ei}")
    ok("points profile", r.status_code == 200 and "total_points" in r.json())

    r = client.get("/api/v1/points/products")
    ok("products list", len(r.json().get("items",[])) >= 1)

    r = client.get(f"/api/v1/points/transactions?elder_id={ei}")
    ok("transactions", r.status_code == 200)

    r = client.get(f"/api/v1/points/orders?elder_id={ei}")
    ok("orders", r.status_code == 200)

    # ===== 9. Edge Cases =====
    sec("9. Edge Cases")
    r = client.get("/api/v1/medications?elder_id=99999")
    ok("nonexistent elder 404", r.status_code == 404)

    r = client.get(f"/api/v1/medications/99999?elder_id={ei}")
    ok("nonexistent med 404", r.status_code == 404)

    r = client.get("/api/v1/points/profile?elder_id=99999")
    ok("nonexistent points 404", r.status_code == 404)

    r = client.post(f"/api/v1/points/redeem?elder_id={ei}&product_id=99999")
    ok("nonexistent product 404", r.status_code == 404)

except Exception as ex:
    print(f"\n[EXCEPTION] {ex}")
    F += 1
    E.append(str(ex))

elapsed = time.time() - start
print(f"\n{'='*50}")
print(f"  Result | Passed: {P} | Failed: {F} | Time: {elapsed:.1f}s")
print(f"{'='*50}")
if E:
    print(f"\nFailures:")
    for e in E:
        print(f"  - {e}")

sys.exit(1 if F > 0 else 0)
