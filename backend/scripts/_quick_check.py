import sqlite3
conn = sqlite3.connect(r'C:\bamabao\backend\bamabao.db')
cur = conn.cursor()

# 索引信息
cur.execute("SELECT * FROM sqlite_master WHERE type='index' AND tbl_name='drug_instructions'")
for r in cur.fetchall():
    print('INDEX:', r)

# 直接恢复到备份
print()
print('正在恢复备份...')
conn.close()

import shutil, os
src = r'C:\bamabao\backend\bamabao_backup_20260725.db'
dst = r'C:\bamabao\backend\bamabao.db'
# sqlite3 可能在文件打开状态，用copy
import subprocess
subprocess.run(['copy', '/y', src, dst], shell=True, capture_output=True)
print('备份恢复完成')
