import sqlite3, os, time

DB = r'C:\bamabao\backend\bamabao.db'
JSON = r'C:\bamabao\backend\scripts\drug_data_full.json'

while True:
    try:
        conn = sqlite3.connect(DB)
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM drug_instructions")
        total = cur.fetchone()[0]
        cur.execute("SELECT category, COUNT(*) FROM drug_instructions GROUP BY category")
        cats = dict(cur.fetchall())
        conn.close()
        
        json_success = 0
        if os.path.exists(JSON):
            import json
            with open(JSON, encoding='utf-8') as f:
                d = json.load(f)
            json_success = len(d.get('success', []))
        
        print(f"\r[{time.strftime('%H:%M:%S')}] DB: {total}种 | JSON: {json_success}已完成 | 分类: {cats}", end='')
        if json_success >= 140:
            print("\n\n✅ 全部完成!")
            break
    except Exception as e:
        print(f"\rError: {e}", end='')
    
    time.sleep(10)
