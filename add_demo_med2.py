import requests, json, sys

BASE = 'http://localhost:8000'

# 1. 发送验证码
r = requests.post(f'{BASE}/api/v1/auth/send-sms', json={'phone': '13800138000'})
print(f'send-sms: {r.status_code}', r.text[:100])

# 2. 验证码登录
r = requests.post(f'{BASE}/api/v1/auth/login/phone', json={
    'phone': '13800138000',
    'code': '123456',
    'role': 'elder'
})
print(f'login phone: {r.status_code}')
if r.status_code != 200:
    print(r.text[:300])
    sys.exit(1)

token = r.json().get('access_token', r.json().get('token'))
print(f'token: {token[:30]}...')
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
uid = r.json().get('user', {}).get('id', 1)

# 3. 添加双时段药品
med_data = {
    "elder_id": uid,
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
    print(f'  OK! ID={r.json().get("id")}')
else:
    print(f'  Failed: {r.text[:200]}')

# 4. 检验打卡API
r = requests.get(f'{BASE}/api/v1/medications/checkin/today?elder_id={uid}', headers=headers)
print(f'\n今日打卡 ({r.status_code}):')
if r.status_code == 200:
    data = r.json()
    for item in data.get('items', []):
        print(f"  {item['name']} - {item['total_slots']}时段/{item['checked_slots']}已打")
        for s in item.get('schedules', []):
            ck = 'Y' if s['checked'] else 'N'
            print(f"    [{ck}] {s['time']}")
    print(f"  剩余: {data.get('total_pending')}次")
