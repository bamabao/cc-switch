"""添加双时段测试药品到种子数据库"""
import requests, json
from datetime import datetime

BASE = 'http://localhost:8000'

# 1. 先登录拿token
r = requests.post(f'{BASE}/api/v1/auth/login', json={
    "phone": "13800138000",
    "password": "123456"
})
print('Login:', r.status_code)
token = r.json().get('access_token')
if not token:
    print('登录失败，尝试用户注册...')
    r = requests.post(f'{BASE}/api/v1/auth/register', json={
        "phone": "13800138000",
        "password": "123456",
        "name": "张奶奶",
        "role": "elder"
    })
    print('Register:', r.status_code, r.text[:100])
    r = requests.post(f'{BASE}/api/v1/auth/login', json={
        "phone": "13800138000",
        "password": "123456"
    })
    token = r.json().get('access_token')

headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
elder_id = 1

# 2. 查药品列表确认现有药
r = requests.get(f'{BASE}/api/v1/medications?elder_id={elder_id}', headers=headers)
print(f'\n现有药品 ({r.status_code}):')
existed = False
for m in r.json().get('items', []):
    if '拜新同' in m.get('name', ''):
        existed = True
        print(f'  拜新同已存在, ID={m["id"]}')

# 3. 添加双时段药品 - 拜新同控释片 (早8点、晚20点)
if not existed:
    med_data = {
        "elder_id": elder_id,
        "name": "拜新同控释片",
        "dosage_per_take": 1,
        "unit": "片",
        "frequency": "每日两次",
        "notes": "降压药，不可掰开服用",
        "total_quantity": 30,
        "status": "approved",
        "schedules": [
            {"time_of_day": "08:00", "dosage": 1},
            {"time_of_day": "20:00", "dosage": 1}
        ]
    }
    r = requests.post(f'{BASE}/api/v1/medications', json=med_data, headers=headers)
    print(f'\n添加拜新同控释片: {r.status_code}')
    if r.status_code in [200, 201]:
        print(f'  ✅ 成功! ID={r.json().get("id")}')
    else:
        print(f'  ❌ 失败: {r.text[:200]}')
else:
    print(f'\n拜新同已存在，跳过')

# 4. 验证打卡API
r = requests.get(f'{BASE}/api/v1/medications/checkin/today?elder_id={elder_id}', headers=headers)
print(f'\n今日打卡状态 ({r.status_code}):')
if r.status_code == 200:
    data = r.json()
    for item in data.get('items', []):
        schedules = item.get('schedules', [])
        print(f"  {item['name']} - {item['total_slots']}时段/{item['checked_slots']}已打")
        for s in schedules:
            check = '✅' if s['checked'] else '🔴'
            print(f"    {check} {s['time']}")
    print(f"  总剩余: {data.get('total_pending')}次")
