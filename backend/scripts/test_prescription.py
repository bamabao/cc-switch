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
        return e.code, e.read().decode()[:500]

def get(path):
    try:
        with urllib.request.urlopen(API + path, timeout=15) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]

print("=== 电子处方全流程测试 ===")

# 1. 医生创建用药方案（医生1 → 患者1，高血压方案：氯沙坦+阿司匹林）
s, r = post('/api/v1/prescription/create', {
    "doctor_id": 1,
    "patient_id": 1,
    "title": "高血压用药方案",
    "summary": "早晚各一次，坚持服用，注意监测血压",
    "disease_group": "高血压组",
    "items": [
        {
            "drug_name": "氯沙坦钾片",
            "category": "oral", "dosage_per_take": 1, "unit": "片",
            "frequency_per_day": 2, "times": ["08:00", "18:00"],
            "meal_relation": "饭后", "duration_days": 30, "total_quantity": 60,
            "notes": "每天早晚各一片"
        },
        {
            "drug_name": "阿司匹林肠溶片",
            "category": "oral", "dosage_per_take": 1, "unit": "片",
            "frequency_per_day": 1, "times": ["08:00"],
            "meal_relation": "饭后", "duration_days": 30, "total_quantity": 30,
            "notes": "每天早上一片"
        }
    ]
})
print(f"1.医生开方案: {s}")
if s == 200:
    print(f"   {r}")
    presc_id = r['prescription_id']
else:
    presc_id = None

# 2. 患者查看待接收
s, r = get('/api/v1/prescription/pending/1')
print(f"2.患者待接收: {s} {len(r['prescriptions'])}个方案")
if s == 200 and r['prescriptions']:
    p = r['prescriptions'][0]
    print(f"   方案: {p['title']} 医生: {p['doctor_name']} 药数: {len(p['items'])}")

# 3. 患者一键接收
if presc_id:
    s, r = post(f'/api/v1/prescription/{presc_id}/accept', {})
    print(f"3.患者接收: {s} {r}")

# 4. 验证药品已创建
s, r = get('/api/v1/medications?elder_id=1')
print(f"4.患者药品列表: {s} {len(r['items'])}种药")
names = [m['name'] for m in r['items']]
print(f"   包含氯沙坦: {'氯沙坦钾片' in names}  包含阿司匹林: {'阿司匹林肠溶片' in names}")

# 5. 历史方案
s, r = get('/api/v1/prescription/history/1')
print(f"5.历史方案: {s} {len(r['prescriptions'])}个")
