import json, urllib.request, urllib.error

API = 'http://localhost:8001'

def post(path, payload):
    req = urllib.request.Request(API + path,
        data=json.dumps(payload, ensure_ascii=False).encode('utf-8'),
        headers={'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]

def get(path):
    try:
        with urllib.request.urlopen(API + path, timeout=10) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]

print("=== 全流程测试 ===")

# 1. 运营看板
s, r = get('/api/v1/admin/dashboard')
print(f"1.看板: {s}")
if s == 200:
    print(f"   用户={r['users']['total_patients']} 医生={r['doctors']['total']} 收入={r['revenue']['total']}")

# 2. 趋势
s, r = get('/api/v1/admin/trend?days=7')
print(f"2.趋势: {s} {len(r['trend'])}天")

# 3. 套餐分布
s, r = get('/api/v1/admin/plan-distribution')
print(f"3.套餐分布: {s} {r['distribution']}")

# 4. 预警
s, r = get('/api/v1/admin/alerts')
print(f"4.预警: {s} {len(r['alerts'])}条")

# 5. 订阅套餐
s, r = post('/api/v1/doctor/subscribe', {"doctor_id": 1, "plan": "personal", "months": 1})
print(f"5.订阅: {s} {r}")

# 6. 确认支付
if s == 200:
    s2, r2 = post(f"/api/v1/doctor/subscribe/confirm?order_no={r['order_no']}&pay_method=wechat", {})
    print(f"6.确认支付: {s2} {r2}")

# 7. 医生信息
s, r = get('/api/v1/doctor/1')
print(f"7.医生信息: {s} 套餐={r['plan']} 名额={r['patient_quota']}")

# 8. 订单列表
s, r = get('/api/v1/admin/orders')
print(f"8.订单: {s} {len(r['orders'])}单")
