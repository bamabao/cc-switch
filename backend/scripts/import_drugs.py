"""
导入爬取的药品数据到数据库
"""
import json
import sys
import urllib.request
import urllib.parse

API = 'http://localhost:8000'

with open(r'C:\bamabao\backend\scripts\drug_data.json', encoding='utf-8') as f:
    data = json.load(f)

results = data['success']
print(f'共 {len(results)} 种药，导入数据库...')

count = 0
for r in results:
    # 通过API导入（调用seed接口的扩展版）
    # 直接POST到后端
    payload = json.dumps({
        'medicine_name': r.get('medicine_name', ''),
        'category': r.get('category', '内服'),
        'adult_dosage': r.get('adult_dosage', '')[:200],
        'child_dosage': r.get('child_dosage', '')[:200],
        'elderly_dosage': r.get('elderly_dosage', '')[:200],
        'contraindications': r.get('contraindications', '')[:500],
        'side_effects': r.get('side_effects', '')[:500],
        'dietary_restrictions': r.get('dietary_restrictions', '')[:200],
        'full_instruction': r.get('full_instruction', '')[:2000],
        'source': 'dayi',
    }).encode()
    try:
        req = urllib.request.Request(
            f'{API}/api/v1/drug/seed',
            data=payload,
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        resp = urllib.request.urlopen(req, timeout=5)
        result = json.loads(resp.read())
        count += result.get('seeded', 0)
        print(f'  {r[\"medicine_name\"][:20]:20s} ✅', end='\r')
    except Exception as e:
        print(f'  {r[\"medicine_name\"][:20]:20s} ❌ {str(e)[:30]}')

print(f'\\n完成！新增 {count} 种药品说明书')
