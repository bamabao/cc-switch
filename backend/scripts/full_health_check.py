"""爸妈宝 全系统体检脚本 — 逐模块测试核心API"""
import json, urllib.request, urllib.error, time, urllib.parse

API = 'http://localhost:8001'
results = []

def _enc(path):
    # 对查询参数做URL编码（中文药名等）
    if '?' in path:
        base, query = path.split('?', 1)
        parts = query.split('&')
        enc_parts = []
        for p in parts:
            if '=' in p:
                k, v = p.split('=', 1)
                enc_parts.append(f"{k}={urllib.parse.quote(v)}")
            else:
                enc_parts.append(urllib.parse.quote(p))
        return base + '?' + '&'.join(enc_parts)
    return path

def post(path, payload=None):
    data = json.dumps(payload, ensure_ascii=False).encode() if payload is not None else b'{}'
    req = urllib.request.Request(API + path, data=data,
        headers={'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:200]
    except Exception as e:
        return -1, str(e)[:200]

def get(path):
    try:
        with urllib.request.urlopen(API + _enc(path), timeout=15) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:200]
    except Exception as e:
        return -1, str(e)[:200]

def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"{'✅' if ok else '❌'} {name}" + (f" — {detail}" if detail and not ok else ""))

# ─── 1. 基础 ───
s, r = get('/api/v1/health')
check("健康检查", s == 200)

# ─── 2. 药品模块 ───
s, r = get('/api/v1/drug/search?name=阿莫西林')
check("药品说明书搜索", s == 200 and len(r.get('items', [])) > 0, f"items={len(r.get('items',[]))}")
s, r = get('/api/v1/drug/search?name=不存在药999')
check("药品搜索无结果", s == 200)

# ─── 3. 用药管理 ───
s, r = get('/api/v1/medications?elder_id=1')
check("药品列表", s == 200 and len(r.get('items', [])) > 0, f"items={len(r.get('items',[]))}")

# ─── 4. 版本 ───
s, r = get('/api/v1/app/version')
check("患者版版本", s == 200 and r.get('version') == '3.9')
s, r = get('/api/v1/app/doctor-version')
check("医生版版本", s == 200 and r.get('version') == '1.0')

# ─── 5. AI ───
s, r = post('/api/v1/ai/ask', {'question': '阿莫西林怎么吃？', 'drug_name': '阿莫西林'})
check("AI问答", s == 200 and 'answer' in r, f"answer={str(r.get('answer',''))[:30]}")

# ─── 6. 医患聊天 ───
s, r = get('/api/v1/chat/history?doctor_id=1&patient_id=1&limit=5')
check("聊天记录", s == 200)
s, r = get('/api/v1/chat/unread-count?doctor_id=1')
check("未读计数", s == 200)

# ─── 7. 医生 ───
s, r = get('/api/v1/doctor/1')
check("医生信息", s == 200 and 'real_name' in r)

# ─── 8. 处方 ───
s, r = get('/api/v1/prescription/history/1')
check("处方历史", s == 200)
s, r = get('/api/v1/prescription/pending/1')
check("待接收处方", s == 200)

# ─── 9. 健康指标 ───
s, r = get('/api/v1/health/latest/1')
check("健康指标最新", s == 200 and len(r.get('latest', {})) > 0, f"latest={len(r.get('latest',{}))}")
s, r = get('/api/v1/health/history/1/blood_pressure?days=3')
check("血压历史", s == 200)

# ─── 10. 睡眠 ───
s, r = get('/api/v1/sleep/latest/1')
check("睡眠最新", s == 200 and r.get('latest') is not None)
s, r = get('/api/v1/sleep/week-summary/1')
check("睡眠周汇总", s == 200)

# ─── 11. ERP ───
s, r = get('/api/v1/erp/products')
check("ERP商品", s == 200 and len(r.get('products', [])) > 0, f"products={len(r.get('products',[]))}")
s, r = get('/api/v1/erp/stock')
check("ERP库存", s == 200)
s, r = get('/api/v1/erp/order/list')
check("ERP订单", s == 200)
s, r = get('/api/v1/erp/trace/TRC-WATCH-K1-001')
check("ERP追溯", s == 200 and r.get('trace_code') == 'TRC-WATCH-K1-001')
s, r = get('/api/v1/erp/trace/INVALID-CODE-999')
check("ERP追溯无效码", s == 404)

# ─── 12. 管理后台 ───
s, r = get('/api/v1/admin/dashboard')
check("运营看板", s == 200 and 'users' in r, f"users={r.get('users')}")
s, r = get('/api/v1/admin/trend')
check("运营趋势", s == 200)

# ─── 13. 认证 ───
s, r = get('/api/v1/auth/me?token=')
check("用户信息(带token)", s in (200, 401, 422))

# ─── 14. 紧急联系人 ───
s, r = get('/api/v1/emergency-contacts')
check("紧急联系人", s == 200)

print(f"\n{'='*50}")
ok_count = sum(1 for _, ok, _ in results if ok)
print(f"体检完成: {ok_count}/{len(results)} 通过")
if ok_count < len(results):
    print("存在失败项，需要修复！")
else:
    print("全部通过 ✅ 系统运行通畅！")
