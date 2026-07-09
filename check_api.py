import requests, json, sys

BASE = 'http://localhost:8000'
r = requests.post(BASE + '/api/v1/auth/login/phone', json={'phone':'13800138000','code':'123456','role':'elder'})
token = r.json()['access_token']
headers = {'Authorization': '***' + token}

print('=== All medications ===')
r = requests.get(BASE + '/api/v1/medications?elder_id=1', headers=headers)
for m in r.json().get('items', []):
    scheds = m.get('schedules', [])
    print(f"  ID={m['id']} {m['name']} status={m.get('status')} slots={len(scheds)}")
    for s in scheds:
        print(f"    time={s['time_of_day']} dose={s['dosage']} active={s.get('is_active')}")

print()
print('=== checkin/today ===')
r = requests.get(BASE + '/api/v1/medications/checkin/today?elder_id=1', headers=headers)
data = r.json()
for item in data.get('items', []):
    print(f"  med_id={item['medication_id']} {item['name']}")
    print(f"    total={item['total_slots']} checked={item['checked_slots']}")
    for s in item.get('schedules', []):
        print(f"    sched_id={s['schedule_id']} time={s['time']} checked={s.get('checked')}")
print(f"  total_pending={data.get('total_pending')}")
