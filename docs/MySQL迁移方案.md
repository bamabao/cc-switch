# 爸妈宝 — MySQL 迁移方案
## Sprint 1 | 负责人：老陈 | 截止：2026-07-03

### 现状
当前后端使用 **SQLite** 开发，数据库文件 `backend/bamabao.db`。SQLite 对开发和测试友好，但不适合生产环境（并发写入锁、无网络访问、备份困难）。

### 目标数据库
**MySQL 8.0** — 王总已拍板 ✅

### 迁移步骤

#### Step 1: 安装 MySQL 8.0
```bash
# Ubuntu/Debian
apt install mysql-server-8.0

# macOS
brew install mysql@8.0

# Windows
# 下载 MySQL Installer: https://dev.mysql.com/downloads/installer/
# 安装时选择 "Server only"，设置 root 密码
```

#### Step 2: 创建数据库和用户
```sql
CREATE DATABASE bamabao
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER 'bamabao'@'%' IDENTIFIED BY 'your-password-here';
GRANT ALL PRIVILEGES ON bamabao.* TO 'bamabao'@'%';
FLUSH PRIVILEGES;
```

#### Step 3: 修改配置
`backend/.env` 文件（从 `.env.example` 复制）：
```ini
DATABASE_URL=mysql+mysqldb://bamabao:your-password@localhost:3306/bamabao
DEBUG=false
```

#### Step 4: 安装 MySQL Python 驱动
```bash
pip install pymysql
# 或
pip install mysqlclient
```

添加到 `requirements.txt`：
```
pymysql==1.1.1
```

#### Step 5: 数据迁移
```bash
# 使用 Alembic 迁移（已有）
cd backend
alembic upgrade head
```

#### 数据迁移（SQLite → MySQL）
如果 SQLite 已有数据，用脚本迁移：
```python
# scripts/migrate_data.py
"""SQLite → MySQL 数据迁移脚本"""
# TODO: 生产数据迁移时实现
# 1. 连接 SQLite 读取所有表数据
# 2. 连接 MySQL
# 3. 逐表插入（注意 ID 自增重置）
# 4. 验证行数一致
```

### 回滚方案
保留 SQLite 数据库文件，确保 `DATABASE_URL` 切回 SQLite 即可恢复。

### Alembic 配置
已有 `alembic.ini` + `migrations/`，迁移脚本已记录所有表结构。
```bash
# 生成新的迁移
alembic revision --autogenerate -m "description"

# 执行迁移
alembic upgrade head

# 回滚
alembic downgrade -1
```
