import json, urllib.request, urllib.error
from datetime import datetime, timedelta

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
        with urllib.request.urlopen(API + path, timeout=15) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]

print("=== 健康指标平台测试（对标Oura Ring） ===")

# 1. 穿戴设备批量上报（模拟爸妈宝手表，血压+心率+血氧+体温）
now = datetime.utcnow()
metrics = []
for i in range(7):
    t = now - timedelta(hours=i)
    metrics.extend([
        {"metric_type": "blood_pressure", "value": 135 + i, "value2": 85 + (i % 3), "unit": "mmHg",
         "measured_at": t.isoformat(), "context": "晨起"},
        {"metric_type": "heart_rate", "value": 70 + i, "unit": "次/分", "measured_at": t.isoformat()},
        {"metric_type": "spo2", "value": 97, "unit": "%", "measured_at": t.isoformat()},
    ])
s, r = post('/api/v1/health/device/batch', {
    "device_id": "bamaobao-watch-demo",
    "device_model": "爸妈宝Watch V1",
    "elder_id": 1,
    "metrics": metrics,
})
print(f"1.手表批量上报: {s} {r}")

# 2. 手动录入血压/血糖/尿酸
for mt, v, v2, ctx in [
    ("blood_pressure", 138, 88, "晨起"),
    ("blood_glucose", 6.2, None, "空腹"),
    ("uric_acid", 420, None, "空腹"),
    ("temperature", 36.8, None, ""),
]:
    s, r = post('/api/v1/health/manual', {
        "elder_id": 1, "metric_type": mt, "value": v, "value2": v2,
        "measured_at": (now - timedelta(hours=2)).isoformat(), "context": ctx,
    })
    print(f"2.手动录入{mt}: {s}")

# 3. 查询血压历史
s, r = get('/api/v1/health/history/1/blood_pressure?days=3')
print(f"3.血压历史: {s} {len(r['data'])}条 config={r['config']['label']}")

# 4. 最新各项指标
s, r = get('/api/v1/health/latest/1')
print(f"4.最新指标: {s}")
for k, v in r['latest'].items():
    print(f"   {k}: {v['value']}{v['unit']}")

# 5. 汇总
s, r = get('/api/v1/health/summary/1/blood_glucose?days=7')
print(f"5.血糖汇总: {s} {r}")
