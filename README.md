# 爸妈宝 🏥

> 老人端 APP + 子女端微信小程序 — 药品全生命周期管理

**让老人用药安全、子女远程放心**

---

## 项目概览

| 维度 | 说明 |
|---|---|
| **定位** | 老人用药管理智慧化平台（纯软件，零硬件） |
| **目标用户** | 60+ 老人（APP端）+ 老人子女（小程序端） |
| **开发周期** | 4 个月（16 周） |
| **当前状态** | 🟢 Sprint 0 完成 90%，进入 Sprint 1 |
| **后端代码** | ~6,200 行 Python (FastAPI) |
| **测试覆盖** | 54 个自动化测试全部通过 |

## 核心功能

### 老人端 APP（Flutter，待开发）
- 📸 药盒拍照录入 + 语音口述录入
- 🔔 超大弹窗用药提醒 + 方言语音播报
- ✅ 一键确认用药 + 积分奖励
- 🏆 积分商城兑换礼品
- 📋 药品档案管理（余量预警、过期提醒）

### 子女端小程序（待开发）
- ✅ 药品审核中心（老人新药需子女审核）
- 💊 远程药品管理
- 📊 用药数据看板（依从率/漏服统计）
- 🛒 积分商城管理端
- 🔔 漏服告警推送

### 后端 API（已就绪 ✅）
| 模块 | 端点数 | 状态 |
|---|---|---|
| 健康检查 | 1 | ✅ |
| 用户认证 | 6 | ✅ |
| 药品管理 | 8 | ✅ |
| 审核日志 | 1 | ✅ |
| 积分商城 | 5 | ✅ |
| **合计** | **21** | **✅ 全部可用** |

## 技术栈

```
后端:     Python 3.11 + FastAPI + SQLAlchemy + Alembic
数据库:   SQLite（开发）/ MySQL 8.0（生产，已确认）
认证:     JWT + 微信 OpenID + 手机验证码
存储:     MinIO（生产）/ Local（开发）
语音:     ☑️ 科大讯飞（推荐，待王总确认）
APP:      ☑️ Flutter（推荐，待王总确认）
小程序:   待开发
CI/CD:    ☑️ GitHub Actions（配置完成）
容器化:   ☑️ Docker + Docker Compose（配置完成）
```

## 项目结构

```
爸妈宝/
├── backend/                  # Python FastAPI 后端
│   ├── app/
│   │   ├── api/              # API 路由（auth/medication/audit/points）
│   │   ├── core/             # 配置
│   │   ├── models/           # 数据模型（8 张表）
│   │   ├── schemas/          # Pydantic 验证
│   │   ├── services/         # 业务服务（reminder/push/scheduler）
│   │   └── main.py           # FastAPI 主入口
│   ├── tests/                # 54 个自动化测试
│   ├── migrations/           # Alembic 迁移
│   ├── Dockerfile
│   └── requirements.txt
├── docs/                     # 文档
│   ├── API文档.md             # 给前端团队的 API 参考
│   ├── 语音SDK选型报告.md      # 科大讯飞 vs 阿里云 vs 微信
│   ├── UI设计规范.md           # 适老化设计规范
│   ├── MySQL迁移方案.md        # SQLite → MySQL 8.0
│   └── 岗位JD-*.md            # 前端岗位 JD
├── app/                      # APP 页面规划
├── miniapp/                  # 小程序页面规划
├── scripts/                  # 运维脚本
│   ├── e2e-verify.py         # 端到端验证
│   └── windows-service.ps1   # 注册 Windows 服务
├── .github/workflows/        # GitHub Actions CI
├── docker-compose.yml
└── 看板.md                   # 项目进度看板
```

## 快速开始

### 后端开发
```bash
cd backend
python -m venv venv
venv\Scripts\activate    # Windows
# source venv/bin/activate  # Linux/Mac
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 运行测试
```bash
cd backend
pytest tests/ -v
```

### API 文档
```bash
# 服务启动后访问
http://localhost:8000/docs        # Swagger UI
http://localhost:8000/redoc       # ReDoc
```

### 一键启动
```powershell
.\backend\start-backend.ps1
```

## 里程碑

| # | 里程碑 | 目标日期 | 状态 |
|---|---|---|---|
| 🏁 M0 | 后端 API 基础可用 | 2026-07-04 | 🟢 **提前完成** |
| 🏁 M1 | 药品全链路闭环 | 2026-07-25 | 🟡 需前端 |
| 🏁 M2 | 积分商城可兑换 | 2026-08-15 | 🟡 需小程序 |
| 🏁 M3 | 子女小程序全功能 | 2026-09-05 | 🔴 高风险 |
| 🏁 M4 | 联调完成 | 2026-09-19 | 🔴 高风险 |
| 🏁 M5 | 正式上线 | 2026-10-03 | 🔴 高风险 |

> 当前瓶颈：APP 前端（Flutter）和小程序前端均待招募，Week 3 前必须进场。

## 需要王总决策

详见 [待办.md](待办.md)
