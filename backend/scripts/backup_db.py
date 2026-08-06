"""爸妈宝 数据库自动备份脚本
- 每天自动备份 bamabao.db
- 保留最近30天备份
- 备份到 C:\bamabao\backups\
"""
import shutil
import os
import sys
from datetime import datetime

DB_PATH = r"C:\bamabao\backend\bamabao.db"
BACKUP_DIR = r"C:\bamabao\backups"
KEEP_DAYS = 30

def backup():
    if not os.path.exists(DB_PATH):
        print(f"❌ 数据库不存在: {DB_PATH}")
        return False

    os.makedirs(BACKUP_DIR, exist_ok=True)

    # 带时间戳的备份文件名
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest = os.path.join(BACKUP_DIR, f"bamabao_{ts}.db")

    # 用sqlite备份（安全方式，防止写入中断）
    try:
        import sqlite3
        src = sqlite3.connect(DB_PATH)
        dst = sqlite3.connect(dest)
        src.backup(dst)
        dst.close()
        src.close()
        print(f"✅ 备份成功: {dest} ({os.path.getsize(dest)} 字节)")
    except Exception as e:
        # 退化为文件复制
        shutil.copy2(DB_PATH, dest)
        print(f"⚠️ 用文件复制完成: {dest} ({os.path.getsize(dest)} 字节) 错误: {e}")

    # 清理旧备份（保留30天）
    cleanup()
    return True

def cleanup():
    """删除30天前的备份"""
    cutoff = datetime.now().timestamp() - KEEP_DAYS * 86400
    removed = 0
    for f in os.listdir(BACKUP_DIR):
        if not f.startswith("bamabao_"):
            continue
        path = os.path.join(BACKUP_DIR, f)
        if os.path.getmtime(path) < cutoff:
            os.remove(path)
            removed += 1
    if removed:
        print(f"🧹 清理了 {removed} 个旧备份")

def list_backups():
    """列出最近的备份"""
    if not os.path.exists(BACKUP_DIR):
        print("暂无备份")
        return
    backups = sorted([f for f in os.listdir(BACKUP_DIR) if f.startswith("bamabao_")], reverse=True)
    print(f"📦 现有备份 {len(backups)} 个（保留30天）:")
    for b in backups[:10]:
        path = os.path.join(BACKUP_DIR, b)
        size = os.path.getsize(path) / 1024 / 1024
        print(f"  {b} ({size:.1f}MB)")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "list":
        list_backups()
    else:
        backup()
