import json, urllib.request, urllib.error
from datetime import date, timedelta

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

print("=== 睡眠监测测试（对标Oura Ring） ===")

# 1. 上报7天睡眠数据（模拟爸妈宝Watch V2指环）
today = date.today()
samples = [
    # (评分, 总时长, 深睡, 浅睡, REM, 清醒, 入睡, 醒来, 心率)
    (88, 455, 95, 240, 95, 25, "22:15", "05:50", 52),
    (82, 430, 80, 230, 90, 30, "23:00", "06:10", 54),
    (75, 400, 70, 215, 85, 30, "23:30", "06:00", 55),
    (91, 470, 105, 245, 100, 20, "22:00", "05:45", 51),
    (68, 360, 60, 190, 80, 30, "00:15", "06:15", 58),
    (79, 420, 85, 220, 85, 30, "22:45", "05:55", 53),
    (86, 445, 90, 235, 95, 25, "22:30", "06:05", 52),
]
for i, (score, total, deep, light, rem, awake, bed, wake, hr) in enumerate(samples):
    d = today - timedelta(days=i)
    s, r = post('/api/v1/sleep/upsert', {
        "elder_id": 1, "sleep_date": d.isoformat(),
        "sleep_score": score, "total_minutes": total,
        "deep_minutes": deep, "light_minutes": light,
        "rem_minutes": rem, "awake_minutes": awake,
        "efficiency": round(total / (total + awake) * 100, 1),
        "bedtime": bed, "wake_time": wake,
        "latency_minutes": 15, "avg_hr": hr, "lowest_hr": hr - 12,
        "avg_hrv": 42, "avg_spo2": 97,
        "source": "wearable", "device_id": "bamaobao-ring-demo",
        "device_model": "爸妈宝Ring V1",
    })
    print(f"1.上报{d}: {s}")

# 2. 最近一晚详情
s, r = get('/api/v1/sleep/latest/1')
print(f"2.最新睡眠: {s}")
if r.get('latest'):
    l = r['latest']
    print(f"   评分:{l['sleep_score']}({l['score_label']}) 时长:{l['total_minutes']}分 "
          f"深睡:{l['deep_minutes']} 浅睡:{l['light_minutes']} REM:{l['rem_minutes']} "
          f"设备:{l['device_model']}")

# 3. 历史
s, r = get('/api/v1/sleep/history/1?days=7')
print(f"3.历史: {s} {len(r['history'])}晚")

# 4. 周汇总
s, r = get('/api/v1/sleep/week-summary/1')
print(f"4.周汇总: {s} {r}")
