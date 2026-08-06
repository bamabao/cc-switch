"""爸妈宝 最终全流程自跑验证 — ERP驾驶舱 + 医生版优化后"""
import json, urllib.request, urllib.error, urllib.parse

API = 'http://localhost:8001'
ok_count = 0
total = 0

def check(name, ok, detail=""):
    global ok_count, total
    total += 1
    if ok: ok_count += 1
    print(f"{'✅' if ok else '❌'} {name}" + (f" — {detail}" if detail and not ok else ""))

def get(path):
    try:
        with urllib.request.urlopen(API + path, timeout=15) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:200]
    except Exception as e:
        return -1, str(e)[:200]

def post(path, payload):
    req = urllib.request.Request(API + path,
        data=json.dumps(payload, ensure_ascii=False).encode(),
        headers={'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:200]
    except Exception as e:
        return -1, str(e)[:200]

print("=" * 55)
print("① ERP → 驾驶舱 打通验证")
s, r = get('/api/v1/admin/dashboard')
erp = r.get('erp', {}) if s == 200 else {}
check("驾驶舱含ERP板块", s == 200 and 'erp' in r, f"erp={erp}")
check("ERP商品数", erp.get('products') == 2, f"products={erp.get('products')}")
check("ERP库存", erp.get('stock') == 63, f"stock={erp.get('stock')}")
check("ERP销售额", erp.get('revenue', 0) > 0, f"revenue={erp.get('revenue')}")
check("ERP低库存预警字段", 'low_stock' in erp)

print("\n② 医生版核心链路（后端支撑）")
s, r = get('/api/v1/doctor/1')
check("医生信息", s == 200)
s, r = get('/api/v1/chat/unread-count?doctor_id=1')
check("未读计数(待办条数据源)", s == 200 and 'unread' in r, f"unread={r.get('unread')}")
s, r = get('/api/v1/chat/history?doctor_id=1&patient_id=1&limit=10')
check("聊天记录(快捷回复发送目标)", s == 200)

print("\n③ ERP业务闭环")
s, r = get('/api/v1/erp/products')
check("商品列表", s == 200 and len(r.get('products', [])) >= 2)
s, r = get('/api/v1/erp/stock')
check("库存总览", s == 200 and len(r.get('stock', [])) >= 2)
s, r = get('/api/v1/erp/order/list')
check("订单列表", s == 200 and len(r.get('orders', [])) >= 1)
s, r = get('/api/v1/erp/trace/TRC-RING-K1-001')
check("二维码追溯", s == 200 and r.get('trace_code') == 'TRC-RING-K1-001')

print("\n④ 健康监测闭环")
s, r = get('/api/v1/health/latest/1')
check("健康指标", s == 200 and len(r.get('latest', {})) >= 3)
s, r = get('/api/v1/sleep/latest/1')
check("睡眠数据", s == 200 and r.get('latest') is not None)

print("\n⑤ 医患协作闭环")
s, r = get('/api/v1/prescription/history/1')
check("处方历史", s == 200 and len(r.get('prescriptions', [])) >= 1)
s, r = get('/api/v1/ai/ask')
check("AI服务在线", s in (200, 405, 422))  # GET会405但服务在

print("\n" + "=" * 55)
print(f"最终结果: {ok_count}/{total} 通过")
if ok_count == total:
    print("🎉 全流程自跑验证通过！系统通畅！")
else:
    print("⚠️ 有失败项")
