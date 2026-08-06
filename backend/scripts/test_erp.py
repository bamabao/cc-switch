import json, urllib.request, urllib.error

API = 'http://localhost:8001'

def post(path, payload=None):
    data = json.dumps(payload, ensure_ascii=False).encode() if payload is not None else b'{}'
    req = urllib.request.Request(API + path, data=data,
        headers={'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:400]

def get(path):
    try:
        with urllib.request.urlopen(API + path, timeout=15) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:400]

print("=== K1穿戴设备商城 + ERP 全流程测试 ===")

# 1. 上架爸妈宝Watch K1（预售）
s, r = post('/api/v1/erp/products', {
    "sku": "BMBW-K1-BLACK", "name": "爸妈宝Watch K1 智能手表",
    "model": "K1", "sub_category": "watch",
    "price": 499, "original_price": 599, "cost_price": 260,
    "stock": 20, "min_stock": 5,
    "image_url": "/mall/watch_k1.png",
    "description": "爸妈宝首款适老智能手表：大字体、服药提醒、心率血压监测、SOS一键呼救",
    "features": '["24小时心率监测","服药提醒震动","SOS一键呼救","IP68防水","7天续航"]',
    "is_pre_order": True, "pre_order_days": 7,
})
print(f"1.上架Watch K1: {s}")
watch_id = r.get('product', {}).get('id') if s == 200 else None

# 2. 上架爸妈宝Ring K1（在售）
s, r = post('/api/v1/erp/products', {
    "sku": "BMBR-K1-TITANIUM", "name": "爸妈宝Ring K1 智能指环",
    "model": "K1", "sub_category": "ring",
    "price": 699, "original_price": 899, "cost_price": 380,
    "stock": 15, "min_stock": 3,
    "image_url": "/mall/ring_k1.png",
    "description": "对标Oura Ring：睡眠分期、HRV、体温、血氧，钛合金轻至3g",
    "features": '["睡眠分期监测","HRV心率变异性","体温趋势","钛合金3g","6-9天续航"]',
    "is_pre_order": False,
})
print(f"2.上架Ring K1: {s}")
ring_id = r.get('product', {}).get('id') if s == 200 else None

# 3. 商品列表
s, r = get('/api/v1/erp/products')
print(f"3.商品列表: {s} {len(r.get('products',[]))}个")
for p in r.get('products', []):
    print(f"   {p['name']} ¥{p['price']} 库存:{p['stock']} 预售:{p['is_pre_order']}")

# 4. 采购入库（补充Watch库存）
s, r = post('/api/v1/erp/purchase/create', {
    "supplier": "华强北供应链", "note": "K1手表补货",
    "items": [{"product_id": watch_id, "quantity": 30, "cost_price": 260}],
})
print(f"4.创建采购单: {s} {r.get('po_no') if s==200 else r}")
po_no = r.get('po_no') if s == 200 else None
if po_no:
    s, r = post(f'/api/v1/erp/purchase/{po_no}/arrive')
    print(f"5.采购入库: {s} {r}")

# 6. 下单购买Ring（在售，扣库存）
s, r = post('/api/v1/erp/order/create', {
    "product_id": ring_id, "buyer_name": "王总", "buyer_phone": "15574001110",
    "buyer_address": "测试地址1号", "quantity": 2,
})
print(f"6.下单Ring: {s}")
order_no = r.get('order', {}).get('order_no') if s == 200 else None

# 7. 支付+发货
if order_no:
    s, r = post(f'/api/v1/erp/order/{order_no}/pay')
    print(f"7.支付: {s}")
    s, r = post(f'/api/v1/erp/order/{order_no}/ship')
    print(f"8.发货: {s} {r}")

# 9. 预售下单Watch
s, r = post('/api/v1/erp/order/create', {
    "product_id": watch_id, "buyer_name": "王总", "quantity": 1,
})
print(f"9.预售下单Watch: {s}")
po2 = r.get('order', {}).get('order_no') if s == 200 else None

# 10. 库存总览
s, r = get('/api/v1/erp/stock')
print(f"10.库存总览: {s} 预警:{r.get('low_count')}个")
for st in r.get('stock', []):
    print(f"    {st['name']} 库存:{st['stock']} 预定:{st['reserved']} 已售:{st['sold']} 可售:{st['available']}")

# 11. 库存流水
s, r = get('/api/v1/erp/stock/logs?limit=10')
print(f"11.库存流水: {s} {len(r.get('logs',[]))}条")
for l in r.get('logs', [])[:5]:
    print(f"    [{l['type']}] {l['product']} {l['quantity']:+d} (库存{l['before']}→{l['after']})")

# 12. 订单列表
s, r = get('/api/v1/erp/order/list')
print(f"12.订单列表: {s} {len(r.get('orders',[]))}单")
for o in r.get('orders', []):
    print(f"    {o['order_no']} {o['product_name']} x{o['quantity']} ¥{o['total_amount']} {o['status']}")
