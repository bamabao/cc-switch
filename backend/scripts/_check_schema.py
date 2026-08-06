import sqlite3
conn = sqlite3.connect(r'C:\bamabao\backend\bamabao.db')
cur = conn.cursor()
# SQLite 建表语句
cur.execute("SELECT sql FROM sqlite_master WHERE name='drug_instructions'")
sql = cur.fetchone()[0]
print(sql)
print('---')
cur.execute("PRAGMA table_info(drug_instructions)")
for c in cur.fetchall():
    print(f'  {c}')
conn.close()
