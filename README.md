# 爸妈宝 👴👵

> **老人用药提醒与健康管理智慧平台**
>
> 子女端微信小程序 + 老人端 Android APP 双端联动，专为独居老人设计的用药全生命周期管理方案。

---

## 📱 产品概览

爸妈宝是一款面向老年人的用药管理与健康陪伴应用，核心解决 **"老人忘记吃药"** 和 **"子女担心老人用药"** 两大痛点。

### 核心业务闭环

```
老人添加药品 → 子女审核 → 定时提醒
         ↓
  老人确认服药 ← 弹窗提醒
         ↓
  获取积分打卡 ← 连续记录
         ↓
  积分商城兑换 ← 正向激励
         ↓
    用药记录台账 → 子女可查
```

---

## 🏗️ 技术架构

```
爸妈宝/
├── app/                    # Flutter Android 前端
│   ├── lib/
│   │   ├── main.dart                  # 应用入口 + 路由
│   │   ├── config/
│   │   │   ├── theme.dart              # 黏土软萌主题 (暖橙#FF9F40/嫩绿#76D160)
│   │   │   └── api_config.dart         # 后端API端点配置
│   │   ├── models/
│   │   │   ├── user.dart               # 用户/积分/商品/订单模型
│   │   │   └── medication.dart         # 药品模型
│   │   ├── services/
│   │   │   └── api_service.dart        # 统一API服务层 (单例+JWT)
│   │   ├── screens/
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart   # 手机号+验证码登录
│   │   │   │   └── kid_binding_screen.dart  # 子女绑定(4步引导)
│   │   │   ├── home/
│   │   │   │   └── home_screen.dart    # 首页(问候+药品数+预警+语音入口)
│   │   │   ├── medicines/
│   │   │   │   ├── medicines_screen.dart    # 药品列表(含详情弹窗)
│   │   │   │   ├── add_medicine_screen.dart # 药品录入(三通道)
│   │   │   │   └── record_screen.dart       # 用药记录(大日历)
│   │   │   ├── mall/
│   │   │   │   └── mall_screen.dart    # 积分商城(含兑换流程)
│   │   │   ├── profile/
│   │   │   │   ├── profile_screen.dart # 个人中心(真实API数据)
│   │   │   │   └── settings_screen.dart # 设置(方言/音量/个人信息)
│   │   │   ├── emergency/
│   │   │   │   └── emergency_screen.dart # 紧急求助(一键拨120)
│   │   │   └── voice/
│   │   │       └── voice_screen.dart    # 语音助手(待接入讯飞)
│   │   └── widgets/
│   │       ├── checkin_popup.dart       # 积分打卡弹窗
│   │       └── medication_reminder_popup.dart  # 用药提醒弹窗
│   └── android/                        # Android原生配置(Kotlin 2.x)
│
├── backend/                 # Python FastAPI 后端
│   └── app/
│       ├── models/                      # SQLAlchemy ORM模型
│       │   ├── user.py                  # User/FamilyBinding
│       │   ├── medication.py            # Medication/MedicationSchedule/MedicationLog
│       │   ├── point.py                 # PointTransaction/PointProduct/PointOrder
│       │   ├── audit.py                 # AuditRecord
│       │   └── base.py                  # 数据库连接/Dependency
│       ├── api/
│       │   ├── auth.py                  # 认证API(登录/发码/绑定/用户信息)
│       │   ├── medication.py            # 药品CRUD/审核/确认/预警
│       │   ├── points.py                # 积分/商城/兑换
│       │   ├── audit.py                 # 操作留痕
│       │   └── health.py                # 健康检查
│       ├── services/
│       │   ├── reminder.py              # 提醒服务(定时检测)
│       │   └── scheduler.py             # 定时器调度
│       └── main.py                      # FastAPI入口
│
├── scripts/                 # 运维脚本
│   ├── fix-sleep.bat                    # 一键关闭Windows睡眠(管理员)
│   ├── watchdog.ps1                     # 看门狗v2(指数退避+事件日志)
│   └── nssm-service-guide.md           # NSSM注册服务指南
│
└── .github/workflows/
    └── ci.yml                           # GitHub Actions (测试+分析+APK+Docker)
```

---

## 🎯 功能清单

| 功能 | 状态 | 备注 |
|------|------|------|
| **手机号+验证码登录** | ✅ | 后端JWT认证，验证码一期mock |
| **子女绑定** | ✅ | 4步引导（扫码/手机号），真实API |
| **首页Dashboard** | ✅ | 动态问候+药品数+预警实时 |
| **药品列表** | ✅ | 点击查看详情（用量/禁忌/副作用） |
| **药品录入** | ✅ | 内服/外用/针剂/滋补四类，三通道入口 |
| **子女审核** | ✅ | Pending→Approve/Reject |
| **定时提醒弹窗** | ✅ | 全屏大字+"我吃好了"三选项 |
| **用药记录日历** | ✅ | 30天台账，绿色=已服/黄色=漏服 |
| **积分打卡激励** | ✅ | 吃药得积分→打卡弹窗（连续天数） |
| **积分商城兑换** | ✅ | 商品列表→确认→兑换→刷新积分 |
| **个人中心** | ✅ | 姓名/积分/连续天数真实API |
| **紧急求助** | ✅ | url_launcher tel:120，5秒取消倒计时 |
| **设置页** | ✅ | 方言切换/音量/个人信息 |
| **语音助手** | 🟡 | UI完成，待接入讯飞语音SDK |
| **相机/相册** | 🟡 | 录入页入口待SDK集成 |
| **Cron晨会** | ✅ | 每日8:00自动出日报 |
| **进度监控** | ✅ | 每2小时检查后端健康+目录变更 |
| **看门狗v2** | ✅ | 指数退避守护后端进程 |
| **睡眠修复脚本** | ✅ | 一键关睡眠待机（需管理员提权） |
| **CI/CD流水线** | ✅ | GitHub Actions全自动 |

---

## 🚀 快速启动

### 前置条件

- **Python 3.11+** (后端)
- **Flutter 3.29+** / **Dart SDK 3.7+** (前端)
- **SQLite** (开发环境，零配置)

### 启动后端

```bash
cd backend
python -m venv venv
venv\Scripts\activate      # Windows
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 构建APK

```bash
cd app
flutter pub get
flutter build apk --debug
```

APK位于：`build/app/outputs/flutter-apk/app-debug.apk`

### 验证

```bash
curl http://localhost:8000/api/v1/health
# {"status":"ok","app":"爸妈宝","version":"0.2.0"}
```

---

## 🗺️ API路由 (20个)

| 方法 | 路由 | 说明 |
|------|------|------|
| `GET` | `/api/v1/health` | 健康检查 |
| `POST` | `/api/v1/auth/login/phone` | 手机号+验证码登录 |
| `POST` | `/api/v1/auth/send-sms` | 发送验证码 |
| `GET` | `/api/v1/auth/me` | 获取用户信息(含积分/家庭成员) |
| `PUT` | `/api/v1/auth/profile` | 更新用户资料 |
| `POST` | `/api/v1/auth/bind-family` | 子女绑定老人 |
| `GET` | `/api/v1/medications` | 药品列表 |
| `POST` | `/api/v1/medications` | 新增药品 |
| `GET` | `/api/v1/medications/pending` | 待审核药品列表 |
| `GET` | `/api/v1/medications/alerts` | 预警列表(过期/余量) |
| `PUT` | `/api/v1/medications/{id}` | 修改药品 |
| `POST` | `/api/v1/medications/{id}/submit` | 提交审核 |
| `POST` | `/api/v1/medications/{id}/audit` | 子女审核 |
| `POST` | `/api/v1/medications/confirm` | 确认用药(产生积分) |
| `GET` | `/api/v1/medications/logs/history` | 用药历史台账 |
| `GET` | `/api/v1/points/profile` | 积分概览 |
| `GET` | `/api/v1/points/transactions` | 积分流水 |
| `GET` | `/api/v1/points/products` | 商品列表 |
| `POST` | `/api/v1/points/redeem` | 积分兑换 |
| `GET` | `/api/v1/points/orders` | 兑换订单 |

---

## 🔧 运维

### 看门狗 (监控后端健康)

已配置 Cron每2小时检查 + 看门狗v2后台进程：
- 指数退避：30s → 60s → 120s → 300s
- Windows事件日志报警
- 自动重启后端进程

### 睡眠修复

```bash
scripts\fix-sleep.bat    # 管理员运行，彻底关睡眠
```

### NSSM注册服务(生产环境)

详见 `scripts/nssm-service-guide.md`，一键注册为Windows服务，开机自启。

---

## 📦 构建记录

| 版本 | 大小 | 时间 | 变更 |
|------|------|------|------|
| v1 | 108MB | - | P0 7页面完成 |
| v2 | 108MB | - | 前后端API接通 |
| v3 | 113MB | 00:18 | 首页+列表对接 |
| v4 | 113MB | 00:21 | 日历+录入+商城 |
| v5 | 113MB | - | 用药积分闭环 |
| v6 | 114MB | 00:27 | send-sms修复 |
| v7 | 114MB | - | 积分商城兑换 |
| v8 | 128MB | 00:42 | url_launcher紧急拨号 |
| **v9** | **128MB** | **01:03** | **积分bug修复+UserProfile重构** |

---

## 👥 团队

| 角色 | 人员 | 职责 |
|------|------|------|
| **总经理** | AI 总经理 | 决策落地、项目推进、代码Review |
| **后端** | 刘工 | FastAPI + 数据库 + CI/CD + 运维脚本 |
| **前端** | 张工 | Flutter UI + 图标 + 适老设计 |
| **客服/售前** | 小蝶 | 知识库+产品资料+客户对接 |

---

## 📝 License

MIT
