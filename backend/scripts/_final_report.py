#!/usr/bin/env python
"""最终报告：爸妈宝药品数据库状态"""
import sqlite3, json

conn = sqlite3.connect(r'C:\bamabao\backend\bamabao.db')
cur = conn.cursor()

cur.execute("SELECT COUNT(*) FROM drug_instructions")
total = cur.fetchone()[0]

cur.execute("SELECT category, COUNT(*) FROM drug_instructions GROUP BY category ORDER BY COUNT(*) DESC")
cats = cur.fetchall()

cur.execute("SELECT source, COUNT(*) FROM drug_instructions GROUP BY source ORDER BY COUNT(*) DESC")
sources = cur.fetchall()

cur.execute("SELECT medicine_name, category, source FROM drug_instructions ORDER BY medicine_name")
all_drugs = cur.fetchall()

conn.close()

print(f'📊 最终数据库状态')
print(f'{"="*50}')
print(f'  总药品数: {total}')
print(f'  分类分布:')
for c, n in cats:
    bar = '█' * (n // 5)
    print(f'    {c}: {n} {bar}')
print(f'  数据来源:')
for s, n in sources:
    print(f'    {s}: {n}')
print(f'{"="*50}')
print(f'\n📋 完整药品清单 ({len(all_drugs)}种):')
for i, (name, cat, src) in enumerate(all_drugs, 1):
    print(f'  {i:3d}. [{cat}] {name} (来源:{src})')
