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

# 1. 医生注册
s, r = post('/api/v1/doctor/register', {
    "phone": "13800001111", "real_name": "王医生", "hospital": "测试医院",
    "department": "内科", "title": "主任医师", "license_no": "110101234567",
    "practice_no": "110102345678", "id_card": "110101198001011234"
})
print(f"1.医生注册: {s} {r}")

# 2. 助理注册
s, r = post('/api/v1/doctor/register-assistant', {
    "phone": "13800002222", "real_name": "李助理", "license_no": "110101111222",
    "id_card": "110101199001011234"
})
print(f"2.助理注册: {s} {r}")

# 3. 看板
s, r = get('/api/v1/admin/dashboard')
print(f"3.运营看板: {s} 用户={r['users']['total_patients']} 医生={r['doctors']['total']} 收入={r['revenue']['total']}")
