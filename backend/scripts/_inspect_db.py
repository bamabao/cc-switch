#!/usr/bin/env python
"""检查爸妈宝数据库：已爬药品列表"""
import sqlite3, json, sys

conn = sqlite3.connect(r'C:\bamabao\backend\bamabao.db')
cur = conn.cursor()

# 列出所有表
cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
tables = cur.fetchall()
print('=== 数据库表 ===')
for t in tables:
    cur.execute(f'PRAGMA table_info("{t[0]}")')
    cols = cur.fetchall()
    cur.execute(f'SELECT COUNT(*) FROM "{t[0]}"')
    cnt = cur.fetchone()[0]
    print(f'  {t[0]}: {cnt}条记录, {len(cols)}列')

# 查 drug_instructions
print('\n=== drug_instructions 表 ===')
try:
    cur.execute("SELECT id, medicine_name, category, source FROM drug_instructions ORDER BY medicine_name")
    rows = cur.fetchall()
    print(f'总计: {len(rows)}条')
    for r in rows:
        print(f'  #{r[0]} {r[1]} [{r[2]}] 来源={r[3]}')
except Exception as e:
    print(f'drug_instructions 表查询失败: {e}')
    # 查有没有其他药品相关表
    for t in tables:
        tn = t[0]
        if 'drug' in tn.lower() or 'medicine' in tn.lower():
            cur.execute(f"SELECT * FROM \"{tn}\" LIMIT 5")
            rows = cur.fetchall()
            col_names = [desc[0] for desc in cur.description]
            print(f'\n{tn} 样例:')
            for r in rows:
                print(dict(zip(col_names, r)))

conn.close()

# 检查 JSON 输出
print('\n=== 爬虫输出文件 drug_data.json ===')
try:
    with open(r'C:\bamabao\backend\scripts\drug_data.json', encoding='utf-8') as f:
        data = json.load(f)
    if isinstance(data, dict):
        succ = data.get('success', [])
        failed = data.get('failed', [])
    elif isinstance(data, list):
        succ = data
        failed = []
    else:
        succ, failed = [], []
    print(f'成功: {len(succ)}, 失败: {len(failed)}')
    for s in succ:
        print(f'  {s.get("medicine_name","?")} | {s.get("source","?")}')
except Exception as e:
    print(f'无法读取: {e}')
