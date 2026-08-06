import json, urllib.request, urllib.error

API = 'http://localhost:8001'

def post(path, payload):
    req = urllib.request.Request(API + path,
        data=json.dumps(payload, ensure_ascii=False).encode('utf-8'),
        headers={'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]

def get(path):
    try:
        with urllib.request.urlopen(API + path, timeout=30) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]

print("=== 医患沟通+助理授权测试 ===")

# 1. 医生审核通过（直接改数据库状态模拟人工审核）
import sys
sys.path.insert(0, r'C:\bamabao\backend')
from app.models.base import SessionLocal
from app.models.doctor import Doctor, DoctorStatus
db = SessionLocal()
for did in [1, 2]:
    d = db.query(Doctor).filter(Doctor.id == did).first()
    if d:
        d.status = DoctorStatus.APPROVED
db.commit()
db.close()
print("1.医生审核通过: OK")

# 2. 医患绑定（患者phone=13800003333需存在，先查现有用户）
s, r = get('/api/v1/medications?elder_id=1')
print(f"2.患者列表检查: {s}")

# 3. 绑定患者（用elder_id=1的患者）
s, r = post('/api/v1/doctor/bind-patient', {"doctor_id": 1, "patient_phone": "13800138000"})
print(f"3.绑定患者: {s} {r}")

# 4. 助理授权
s, r = post('/api/v1/assistant/invite', {
    "doctor_id": 1, "assistant_phone": "13800002222",
    "can_reply": True, "can_view_data": True, "need_approval": True,
    "patient_ids": [1]
})
print(f"4.助理授权: {s} {r}")

# 5. 患者发消息（带AI建议回复）
s, r = post('/api/v1/chat/send', {
    "doctor_id": 1, "patient_id": 1, "sender_role": "patient", "sender_id": 1,
    "content": "医生您好，我这两天吃阿莫西林有点头晕，需要停药吗？"
})
print(f"5.患者发消息: {s}")
if s == 200:
    print(f"   紧急: {r['is_emergency']}")
    print(f"   AI建议: {json.dumps(r['ai_suggestions'], ensure_ascii=False)[:200]}")

# 6. 聊天记录
s, r = get('/api/v1/chat/history?doctor_id=1&patient_id=1')
print(f"6.聊天记录: {s} {len(r)}条")

# 7. 未读计数
s, r = get('/api/v1/chat/unread-count?doctor_id=1')
print(f"7.未读: {s} {r}")

# 8. 助理列表
s, r = get('/api/v1/assistant/list/1')
print(f"8.助理列表: {s} {r['assistants']}")

# 9. 紧急消息测试
s, r = post('/api/v1/chat/send', {
    "doctor_id": 1, "patient_id": 1, "sender_role": "patient", "sender_id": 1,
    "content": "医生我呼吸困难喘不上气！"
})
print(f"9.紧急消息: {s} 紧急={r.get('is_emergency') if s==200 else r}")

# 10. 撤销助理
s, r = post('/api/v1/assistant/revoke', {"doctor_id": 1, "assistant_id": 2})
print(f"10.撤销助理: {s} {r}")
