# 爸妈宝 API 文档

> 版本：v0.2.0  
> 基础 URL：`http://<host>:8000`  
> 最后更新：2026-06-29  
> 目标平台：Flutter（老人端 APP）、微信小程序（子女端）
> 端点总数：21

---

## 目录

1. [概览](#1-概览)
2. [认证方式](#2-认证方式)
3. [API 端点详述](#3-api-端点详述)
   - [3.1 健康检查](#31-健康检查)
   - [3.2 用户认证](#32-用户认证)
   - [3.3 药品管理](#33-药品管理)
   - [3.4 审核日志](#34-审核日志)
   - [3.5 积分商城](#35-积分商城)
4. [数据模型定义](#4-数据模型定义)
5. [业务流程图示](#5-业务流程图示)
6. [错误码说明](#6-错误码说明)
7. [附录：枚举与状态流转](#7-附录枚举与状态流转)

---

## 1. 概览

### 项目简介

**爸妈宝** 是一款面向家庭的全生命周期药品管理平台。包含两大客户端：

| 端 | 技术栈 | 用户角色 | 核心功能 |
|---|---|---|---|
| 老人端 APP | Flutter | `elder` | 查看药单、用药提醒、确认用药、积分商城 |
| 子女端小程序 | 微信小程序 | `child` | 扫码/手动录入药品、审核用药、查看台账 |

### 角色说明

- **`elder`** — 老人。用药的当事人，可在手机 APP 内确认用药、查看积分。
- **`child`** — 子女。通过小程序管理药品信息、审核用药、查看历史台账。

### 接口风格

- RESTful API，请求/响应体均为 `application/json`
- 一期 token 通过 Query 参数传递，生产环境建议迁移至 `Authorization: Bearer <token>` Header
- 时间格式：`YYYY-MM-DD`（日期）、`HH:mm`（时刻）、`YYYY-MM-DD HH:mm:ss`（完整时间戳）
- 所有 POST/PUT 请求体 Content-Type 均为 `application/json`

---

## 2. 认证方式

### 一期（当前实现）

Token 通过 **Query 参数** 传递：

```
GET /api/v1/auth/me?token=xxxxx
POST /api/v1/medications?elder_id=1&token=xxxxx
```

> **注意：** 一期仅用于快速开发联调，生产环境前需改为 `Authorization: Bearer <token>` 方式。

### 生产环境（推荐）

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

### Token 获取流程

见下方 [3.2 用户认证](#32-用户认证) 中的登录端点。

---

## 3. API 端点详述

---

### 3.1 健康检查

#### `GET /api/v1/health`

健康检查端点，用于监控和 CI/CD 探活。

**参数：** 无

**响应示例：**

```json
{
  "status": "ok",
  "app": "爸妈宝",
  "version": "0.1.0"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| status | string | `"ok"` 表示服务正常 |
| app | string | 应用名称 |
| version | string | 当前 API 版本 |

---

### 3.2 用户认证

> 前缀：`/api/v1/auth`

---

#### `POST /api/v1/auth/login/wechat`

微信登录（子女小程序端使用）。

**流程：** 小程序调用 `wx.login()` 获取临时 `code` → 传入本接口换取业务 Token。

**请求体：**

```json
{
  "code": "wx_xxxxxxxxxxxxx",
  "role": "child"
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| code | string | 是 | 微信临时登录凭证（通过 `wx.login()` 获取） |
| role | string | 是 | 用户角色，可选值：`"child"` / `"elder"` |

**响应：** `TokenResponse`

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "user_id": 1,
  "role": "child",
  "nickname": "小明"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| access_token | string | JWT Token |
| user_id | integer | 用户 ID |
| role | string | `"child"` / `"elder"` |
| nickname | string | 用户微信昵称 |

---

#### `POST /api/v1/auth/login/phone`

手机验证码登录（老人端 APP 使用）。

**流程：** 用户输入手机号 → APP 调用 `send-sms` → 用户输入收到的验证码 → 调用本接口。

**请求体：**

```json
{
  "phone": "13812345678",
  "code": "123456",
  "role": "elder"
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| phone | string | 是 | 手机号码 |
| code | string | 是 | 短信验证码 |
| role | string | 是 | 必须为 `"elder"` |

**响应：** `TokenResponse`

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "user_id": 2,
  "role": "elder",
  "nickname": "张爷爷"
}
```

---

#### `POST /api/v1/auth/send-sms`

发送短信验证码（一期为 Mock 实现）。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| phone | string | 是 | 接收验证码的手机号 |

> 请求体无 body。

**响应：**

```json
{
  "message": "验证码已发送",
  "code": "123456"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| message | string | 提示信息 |
| code | string | 验证码（一期 Mock 直接返回，方便联调；生产环境不返回 code） |

> **联调提示：** 一期每次请求无论手机号，验证码均为 `"123456"`。

---

#### `POST /api/v1/auth/bind-family`

子女绑定老人（建立家庭关系）。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| child_id | integer | 是 | 子女端用户 ID |
| token | string | 是 | 认证 Token |

**请求体：**

```json
{
  "elder_phone": "13812345678"
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_phone | string | 是 | 老人手机号（需已在系统中注册） |

**响应：**

```json
{
  "message": "绑定成功",
  "elder_id": 2,
  "elder_nickname": "张爷爷"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| message | string | 操作结果 |
| elder_id | integer | 老人用户 ID |
| elder_nickname | string | 老人昵称 |

---

#### `GET /api/v1/auth/me`

获取当前登录用户信息。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| token | string | 是 | 当前用户 Token |

**响应：** `UserInfoResponse`

```json
{
  "id": 1,
  "nickname": "小明",
  "avatar_url": "https://wx.qlogo.cn/xxx",
  "role": "child",
  "phone": "13812345678",
  "voice_preference": "woman",
  "font_scale": 1.2,
  "total_points": 580,
  "current_streak": 7,
  "family_members": [
    {
      "user_id": 2,
      "nickname": "张爷爷",
      "relation": "爸爸"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | integer | 用户 ID |
| nickname | string | 昵称 |
| avatar_url | string | 头像 URL |
| role | string | `"child"` / `"elder"` |
| phone | string | 手机号 |
| voice_preference | string | 语音偏好（见 3.2.6） |
| font_scale | number | 字体缩放比例（老人端专用） |
| total_points | integer | 总积分（老人） |
| current_streak | integer | 当前连续用药天数 |
| family_members | array | 家庭成员列表 |

> **说明：** `family_members` 对于角色 `"elder"` 返回绑定其的子女信息；对于 `"child"` 返回其绑定的老人信息。

---

#### `PUT /api/v1/auth/profile`

更新当前用户资料。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| token | string | 是 | 认证 Token |

**请求体（所有字段均可选，只传需要修改的）：**

```json
{
  "nickname": "新昵称",
  "avatar_url": "https://cdn.xxx/avatar.jpg",
  "voice_preference": "woman",
  "font_scale": 1.5
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| nickname | string | 否 | 修改昵称 |
| avatar_url | string | 否 | 修改头像 URL |
| voice_preference | string | 否 | 语音偏好：`"man"` / `"woman"` / `"none"` |
| font_scale | number | 否 | 字体缩放倍数，范围 1.0~2.0（老人端专属） |

**响应：** `UserInfoResponse`（同 `GET /me` 返回结构）

---

### 3.3 药品管理

> 前缀：`/api/v1/medications`

药品的完整生命周期：**新建 → 待审核 → 审核通过/驳回 → 用药确认 → 历史台账**

---

#### `GET /api/v1/medications`

获取药品列表（按老人筛选）。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人用户 ID |
| category | string | 否 | 药品分类筛选：`"oral"` / `"external"` / `"injection"` / `"supplement"` |
| status | string | 否 | 审核状态筛选：`"pending"` / `"approved"` / `"rejected"` |
| token | string | 是 | 认证 Token |

**响应：**

```json
[
  {
    "id": 1,
    "category": "oral",
    "name": "阿莫西林胶囊",
    "manufacturer": "白云山制药",
    "expiry_date": "2026-12-31",
    "total_quantity": 24,
    "unit": "粒",
    "remaining_quantity": 18,
    "status": "approved",
    "notes": "每日3次，每次2粒",
    "dosage_per_take": 2,
    "frequency_per_day": 3,
    "meal_relation": "饭后",
    "oral_form": "capsule",
    "schedules": [
      {"id": 1, "time_of_day": "08:00", "dosage": 2, "dosage_display": "2粒"},
      {"id": 2, "time_of_day": "13:00", "dosage": 2, "dosage_display": "2粒"},
      {"id": 3, "time_of_day": "20:00", "dosage": 2, "dosage_display": "2粒"}
    ],
    "created_at": "2026-06-01 10:30:00",
    "updated_at": "2026-06-28 08:00:00"
  }
]
```

> **字段说明：** 每个药品对象包含完整的药品信息（详见 [4. 数据模型定义](#4-数据模型定义)）。

---

#### `POST /api/v1/medications`

新增药品（子女端录入）。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| token | string | 是 | 认证 Token |

**请求体（完整示例见下方分类型说明）：**

**口服药 (category: `"oral"`)**

```json
{
  "category": "oral",
  "name": "阿莫西林胶囊",
  "manufacturer": "白云山制药",
  "expiry_date": "2026-12-31",
  "total_quantity": 24,
  "unit": "粒",
  "notes": "每日3次，每次2粒",
  "oral_form": "capsule",
  "dosage_per_take": 2,
  "frequency_per_day": 3,
  "meal_relation": "饭后",
  "schedules": [
    {"time_of_day": "08:00", "dosage": 2, "dosage_display": "2粒"},
    {"time_of_day": "13:00", "dosage": 2, "dosage_display": "2粒"},
    {"time_of_day": "20:00", "dosage": 2, "dosage_display": "2粒"}
  ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| category | string | 是 | 固定为 `"oral"` |
| name | string | 是 | 药品名称 |
| manufacturer | string | 否 | 生产厂家 |
| expiry_date | string | 否 | 有效期，格式 `YYYY-MM-DD` |
| total_quantity | number | 是 | 总数量 |
| unit | string | 是 | 单位（粒/袋/瓶等） |
| notes | string | 否 | 备注说明 |
| **oral_form** | string | 是 | 剂型：`"tablet"` / `"capsule"` / `"granule"` / `"oral_liquid"` / `"decoction"` |
| dosage_per_take | number | 是 | 每次用量 |
| frequency_per_day | number | 是 | 每日次数 |
| meal_relation | string | 否 | 餐前/餐后：`"饭前"` / `"饭后"` / `"空腹"` / `""` |
| schedules | array | 是 | 服药时间安排（见下方） |

**Schedule 子对象：**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| time_of_day | string | 是 | 时间，格式 `HH:mm` |
| dosage | number | 是 | 本次用量（数值） |
| dosage_display | string | 是 | 用量展示文本，如 `"2粒"`、`"1袋"` |

**外用药 (category: `"external"`)**

```json
{
  "category": "external",
  "name": "云南白药膏",
  "manufacturer": "云南白药",
  "expiry_date": "2027-06-01",
  "total_quantity": 10,
  "unit": "贴",
  "notes": "外用，每日1次",
  "external_form": "patch",
  "usage_method": "贴于患处",
  "frequency_per_day": 1,
  "schedules": [
    {"time_of_day": "21:00", "dosage": 1, "dosage_display": "1贴"}
  ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| category | string | 是 | 固定为 `"external"` |
| **external_form** | string | 是 | 外用剂型：`"ointment"` / `"spray"` / `"drops"` / `"patch"` / `"iodophor"` / `"lotion"` |
| usage_method | string | 否 | 使用方法描述 |
| frequency_per_day | number | 是 | 每日次数 |
| schedules | array | 是 | 用药时间安排 |

**注射剂 (category: `"injection"`)**

```json
{
  "category": "injection",
  "name": "胰岛素注射液",
  "manufacturer": "诺和诺德",
  "expiry_date": "2026-10-01",
  "total_quantity": 1,
  "unit": "支",
  "notes": "每日早晚各一次",
  "injection_form": "insulin",
  "dosage_per_take": 10,
  "dosage_unit": "单位",
  "frequency_per_day": 2,
  "meal_relation": "饭前",
  "schedules": [
    {"time_of_day": "07:30", "dosage": 10, "dosage_display": "10单位"},
    {"time_of_day": "18:30", "dosage": 10, "dosage_display": "10单位"}
  ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| category | string | 是 | 固定为 `"injection"` |
| **injection_form** | string | 是 | 注射剂型：`"insulin"` / `"subcutaneous"` / `"long_acting"` / `"infusion"` |
| dosage_unit | string | 否 | 剂量单位（默认 `"单位"`） |

**保健品 (category: `"supplement"`)**

```json
{
  "category": "supplement",
  "name": "维生素D3滴剂",
  "manufacturer": "汤臣倍健",
  "expiry_date": "2027-12-01",
  "total_quantity": 60,
  "unit": "粒",
  "notes": "每日1次，随餐服用",
  "dosage_per_take": 1,
  "frequency_per_day": 1,
  "meal_relation": "随餐",
  "schedules": [
    {"time_of_day": "12:00", "dosage": 1, "dosage_display": "1粒"}
  ]
}
```

> **注意：** 保健品无独立 `_form` 字段，用 `dosage_per_take` / `frequency_per_day` / `schedules` 通用字段即可。

**通用必填字段（所有分类）：**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| category | string | 是 | `"oral"` / `"external"` / `"injection"` / `"supplement"` |
| name | string | 是 | 药品名称 |
| total_quantity | number | 是 | 总数量 |
| unit | string | 是 | 单位 |

> **新增后状态：** 创建成功后药品的 `status` 自动为 `"pending"`，需经子女审核通过后方可生效。

**响应：** 创建的完整药品对象（同 `GET /medications` 列表项结构）。

---

#### `GET /api/v1/medications/pending`

获取待审核药品列表。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| token | string | 是 | 认证 Token |

**响应：** 药品列表，仅包含 `status === "pending"` 的药品。

---

#### `GET /api/v1/medications/alerts`

获取老人的药品预警列表（过期、余量不足等）。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| token | string | 是 | 认证 Token |

**响应：**

```json
{
  "items": [
    {
      "medication_id": 1,
      "medication_name": "硝苯地平缓释片",
      "alerts": [
        {
          "type": "stock",
          "severity": "warning",
          "message": "药品「硝苯地平缓释片」余量不足（约7天用量）",
          "stock_days": 7
        }
      ]
    }
  ],
  "total": 1
}
```

**预警类型：**

| type | severity | 说明 |
|---|---|---|
| `expired` | `danger` | 已过保质期 |
| `expiry` | `warning` | 距过期不足30天 |
| `stock` | `warning` | 余量不足7天 |

---

#### `GET /api/v1/medications/{medication_id}`

获取单个药品详情。

**Path 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| medication_id | integer | 是 | 药品 ID |

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID（权限校验） |
| token | string | 是 | 认证 Token |

**响应：** 完整药品对象。

---

#### `PUT /api/v1/medications/{medication_id}`

修改药品信息。

**Path 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| medication_id | integer | 是 | 药品 ID |

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| token | string | 是 | 认证 Token |

**请求体：** `MedicationUpdate`

仅填写需要更改的字段，未传的字段保持不变。

```json
{
  "notes": "更新后的备注",
  "dosage_per_take": 3,
  "schedules": [
    {"time_of_day": "08:00", "dosage": 3, "dosage_display": "3粒"}
  ]
}
```

> **重要：** 修改后药品 `status` 自动重置为 `"pending"`，需重新审核。

**响应：** 更新后的完整药品对象。

---

#### `POST /api/v1/medications/{medication_id}/submit`

提交药品审核。当药品被驳回后，修改后可调用本接口重新进入审核流程。

**Path 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| medication_id | integer | 是 | 药品 ID |

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| token | string | 是 | 认证 Token |

**请求体：** 无 body。

**响应：**

```json
{
  "message": "提交审核成功",
  "medication_id": 1,
  "status": "pending"
}
```

---

#### `POST /api/v1/medications/{medication_id}/audit`

审核药品（子女端操作）。

**Path 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| medication_id | integer | 是 | 药品 ID |

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| child_id | integer | 是 | 子女用户 ID（权限校验） |
| token | string | 是 | 认证 Token |

**请求体：**

```json
{
  "action": "approve",
  "reject_reason": ""
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| action | string | 是 | `"approve"` — 通过 / `"reject"` — 驳回 |
| reject_reason | string | 否 | 驳回原因（`action` 为 `"reject"` 时建议填写） |

**响应（通过）：**

```json
{
  "message": "审核通过",
  "medication_id": 1,
  "status": "approved"
}
```

**响应（驳回）：**

```json
{
  "message": "已驳回",
  "medication_id": 1,
  "status": "rejected",
  "reject_reason": "剂量填写有误，请确认后重提"
}
```

---

#### `POST /api/v1/medications/confirm`

确认用药（老人端 APP 操作）。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| token | string | 是 | 认证 Token |

**请求体：**

```json
{
  "medication_id": 1,
  "schedule_id": 2,
  "dosage_taken": 2.0,
  "remark": ""
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| medication_id | integer | 是 | 药品 ID |
| schedule_id | integer | 是 | 用药时间安排 ID（来自 schedules 数组） |
| dosage_taken | float | 否 | 实际服用剂量（不传则使用默认剂量） |
| remark | string | 否 | 备注说明（如"今日少服半粒"等） |

> **确认后效果：** 记录用药日志、扣除药品余量、累计积分。

**响应：**

```json
{
  "message": "用药确认成功",
  "medication_id": 1,
  "schedule_id": 2,
  "points_earned": 10,
  "remaining_quantity": 18
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| points_earned | integer | 本次确认获得的积分 |
| remaining_quantity | number | 该药剩余数量 |

---

#### `GET /api/v1/medications/logs/history`

用药历史台账。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| medication_id | integer | 否 | 按药品筛选 |
| days | integer | 否 | 最近天数，默认 `7` |
| token | string | 是 | 认证 Token |

**响应：**

```json
[
  {
    "id": 1,
    "medication_id": 1,
    "medication_name": "阿莫西林胶囊",
    "schedule_time": "08:00",
    "dosage_taken": 2.0,
    "dosage_display": "2粒",
    "taken_at": "2026-06-28 08:05:00",
    "remark": ""
  },
  {
    "id": 2,
    "medication_id": 1,
    "medication_name": "阿莫西林胶囊",
    "schedule_time": "13:00",
    "dosage_taken": 2.0,
    "dosage_display": "2粒",
    "taken_at": "2026-06-28 13:02:00",
    "remark": ""
  }
]
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | integer | 用药记录 ID |
| medication_id | integer | 药品 ID |
| medication_name | string | 药品名称 |
| schedule_time | string | 排定的服药时间 `HH:mm` |
| dosage_taken | float | 实际服用剂量 |
| dosage_display | string | 用量展示文本 |
| taken_at | string | 确认用药的时间戳 |
| remark | string | 备注 |

---

### 3.4 审核日志

> 前缀：`/api/v1/audit`

#### `GET /api/v1/audit/history`

操作留痕记录。记录所有对药品的创建、修改、审核等操作。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| medication_id | integer | 否 | 按药品筛选 |
| days | integer | 否 | 最近天数，默认 `30` |
| token | string | 是 | 认证 Token |

**响应：**

```json
[
  {
    "id": 1,
    "medication_id": 1,
    "medication_name": "阿莫西林胶囊",
    "action": "create",
    "operator_id": 1,
    "operator_nickname": "小明",
    "operator_role": "child",
    "detail": "新增药品",
    "created_at": "2026-06-01 10:30:00"
  },
  {
    "id": 2,
    "medication_id": 1,
    "action": "submit_audit",
    "operator_id": 1,
    "operator_nickname": "小明",
    "operator_role": "child",
    "detail": "提交审核",
    "created_at": "2026-06-01 10:30:05"
  },
  {
    "id": 3,
    "medication_id": 1,
    "action": "audit_approve",
    "operator_id": 1,
    "operator_nickname": "小明",
    "operator_role": "child",
    "detail": "审核通过",
    "created_at": "2026-06-01 11:00:00"
  }
]
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | integer | 日志 ID |
| medication_id | integer | 关联药品 ID |
| medication_name | string | 药品名称 |
| action | string | 操作类型：`"create"` / `"update"` / `"submit_audit"` / `"audit_approve"` / `"audit_reject"` / `"confirm_take"` |
| operator_id | integer | 操作人 ID |
| operator_nickname | string | 操作人昵称 |
| operator_role | string | `"child"` / `"elder"` |
| detail | string | 操作详情描述 |
| created_at | string | 操作时间 |

---

### 3.5 积分商城

> 前缀：`/api/v1/points`

积分系统用于激励老人按时用药。每次确认用药可获得积分，积分可在商城兑换实物。

---

#### `GET /api/v1/points/profile`

获取老人积分概览。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| token | string | 是 | 认证 Token |

**响应：**

```json
{
  "total_points": 580,
  "current_streak": 7,
  "longest_streak": 15,
  "today_earned": 10
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| total_points | integer | 总积分余额 |
| current_streak | integer | 当前连续用药天数 |
| longest_streak | integer | 历史最长连续用药天数 |
| today_earned | integer | 今日已获得积分 |

---

#### `GET /api/v1/points/transactions`

获取积分流水记录。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| limit | integer | 否 | 每页条数，默认 `50` |
| offset | integer | 否 | 偏移量，默认 `0` |
| token | string | 是 | 认证 Token |

**响应：**

```json
[
  {
    "id": 1,
    "amount": 10,
    "type": "earn",
    "description": "用药确认 - 阿莫西林胶囊",
    "created_at": "2026-06-28 08:05:00"
  },
  {
    "id": 2,
    "amount": -100,
    "type": "redeem",
    "description": "兑换 - 老花镜",
    "created_at": "2026-06-25 14:30:00"
  }
]
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | integer | 流水 ID |
| amount | integer | 变动积分（正数=获得，负数=消耗） |
| type | string | `"earn"` / `"redeem"` / `"system"` |
| description | string | 交易描述 |
| created_at | string | 交易时间 |

---

#### `GET /api/v1/points/products`

获取可兑换商品列表。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| category | string | 否 | 商品分类筛选：`"daily"` / `"health"` / `"entertainment"` |
| token | string | 否 | 认证 Token（公开浏览也可不传） |

**响应：**

```json
[
  {
    "id": 1,
    "name": "老花镜",
    "description": "防蓝光老花镜，适合阅读",
    "image_url": "https://cdn.xxx/glasses.jpg",
    "price": 200,
    "stock": 50,
    "category": "daily"
  },
  {
    "id": 2,
    "name": "电子血压计",
    "description": "上臂式全自动血压计",
    "image_url": "https://cdn.xxx/bp.jpg",
    "price": 500,
    "stock": 10,
    "category": "health"
  }
]
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | integer | 商品 ID |
| name | string | 商品名称 |
| description | string | 商品描述 |
| image_url | string | 商品图片 URL |
| price | integer | 所需积分 |
| stock | integer | 库存数量 |
| category | string | `"daily"` / `"health"` / `"entertainment"` |

---

#### `POST /api/v1/points/redeem`

积分兑换商品。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| product_id | integer | 是 | 商品 ID |
| token | string | 是 | 认证 Token |

**响应：**

```json
{
  "message": "兑换成功",
  "order_id": 1,
  "points_remaining": 480
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| message | string | 操作提示 |
| order_id | integer | 兑换订单 ID |
| points_remaining | integer | 兑换后剩余积分 |

---

#### `GET /api/v1/points/orders`

获取兑换订单列表。

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| elder_id | integer | 是 | 老人 ID |
| token | string | 是 | 认证 Token |

**响应：**

```json
[
  {
    "order_id": 1,
    "product_name": "老花镜",
    "price": 200,
    "status": "pending",
    "created_at": "2026-06-25 14:30:00"
  },
  {
    "order_id": 2,
    "product_name": "电子血压计",
    "price": 500,
    "status": "shipped",
    "created_at": "2026-06-20 09:15:00"
  }
]
```

| 字段 | 类型 | 说明 |
|---|---|---|
| order_id | integer | 订单 ID |
| product_name | string | 兑换的商品名称 |
| price | integer | 消耗积分 |
| status | string | `"pending"` / `"shipped"` / `"completed"` / `"cancelled"` |
| created_at | string | 兑换时间 |

---

## 4. 数据模型定义

### 4.1 用户（User）

```json
{
  "id": "integer",
  "openid": "string | null",
  "phone": "string | null",
  "nickname": "string",
  "avatar_url": "string",
  "role": "child | elder",
  "voice_preference": "man | woman | none",
  "font_scale": "number (1.0~2.0)"
}
```

### 4.2 药品（Medication）

```json
{
  "id": "integer",
  "elder_id": "integer",
  "creator_id": "integer",
  "category": "oral | external | injection | supplement",
  "name": "string",
  "manufacturer": "string | null",
  "expiry_date": "date | null",
  "total_quantity": "number",
  "remaining_quantity": "number",
  "unit": "string",
  "status": "pending | approved | rejected",
  "notes": "string | null",
  "dosage_per_take": "number | null",
  "frequency_per_day": "number | null",
  "meal_relation": "string | null",
  "usage_method": "string | null (外用药专用)",
  "oral_form": "string | null",
  "external_form": "string | null",
  "injection_form": "string | null",
  "dosage_unit": "string | null (注射剂专用)",
  "schedules": "Schedule[]",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### 4.3 服药时间安排（Schedule）

```json
{
  "id": "integer",
  "medication_id": "integer",
  "time_of_day": "HH:mm",
  "dosage": "number",
  "dosage_display": "string"
}
```

### 4.4 TokenResponse

```json
{
  "access_token": "string",
  "user_id": "integer",
  "role": "child | elder",
  "nickname": "string"
}
```

### 4.5 UserInfoResponse

```json
{
  "id": "integer",
  "nickname": "string",
  "avatar_url": "string",
  "role": "child | elder",
  "phone": "string | null",
  "voice_preference": "man | woman | none",
  "font_scale": "number",
  "total_points": "integer",
  "current_streak": "integer",
  "family_members": [
    {
      "user_id": "integer",
      "nickname": "string",
      "relation": "string"
    }
  ]
}
```

### 4.6 用药记录（MedicationLog）

```json
{
  "id": "integer",
  "medication_id": "integer",
  "elder_id": "integer",
  "schedule_id": "integer",
  "scheduled_time": "HH:mm",
  "dosage_taken": "number",
  "dosage_display": "string",
  "taken_at": "datetime",
  "remark": "string | null"
}
```

### 4.7 审核日志（AuditLog）

```json
{
  "id": "integer",
  "medication_id": "integer",
  "action": "string",
  "operator_id": "integer",
  "operator_nickname": "string",
  "detail": "string",
  "created_at": "datetime"
}
```

### 4.8 积分流水（PointTransaction）

```json
{
  "id": "integer",
  "elder_id": "integer",
  "amount": "integer",
  "type": "earn | redeem | system",
  "description": "string",
  "created_at": "datetime"
}
```

### 4.9 商品（Product）

```json
{
  "id": "integer",
  "name": "string",
  "description": "string",
  "image_url": "string",
  "price": "integer (所需积分)",
  "stock": "integer",
  "category": "daily | health | entertainment"
}
```

### 4.10 兑换订单（RedemptionOrder）

```json
{
  "order_id": "integer",
  "elder_id": "integer",
  "product_id": "integer",
  "product_name": "string",
  "price": "integer",
  "status": "pending | shipped | completed | cancelled",
  "created_at": "datetime"
}
```

---

## 5. 业务流程图示

### 5.1 药品全生命周期

```
创建药品（子女端）
    │
    ▼
状态: pending ────→ 子女审核（audit）
    │                    │
    │              ┌─────┴─────┐
    │              ▼           ▼
    │           approved    rejected
    │                         │
    │                   子女修改(put) ──→ submit ──→ pending
    │                         │
    └─────────────────────────┘
        修改后状态重置为 pending

approved 状态下：
    │
    ▼
老人按服药时间确认用药（confirm）
    │
    ├── 记录用药日志
    ├── 扣除药品余量
    └── 增加积分
```

### 5.2 用户登录流程

**子女端（微信小程序）：**

```
打开小程序
    │
wx.login() ──→ 获取临时 code
    │
POST /login/wechat {code, role:"child"}
    │
    ▼
返回 TokenResponse ──→ 存储 token 到 storage
    │
    ▼
GET /me?token=xxx ──→ 加载用户信息
```

**老人端（Flutter APP）：**

```
打开 APP
    │
输入手机号
    │
POST /send-sms?phone=xxx
    │
    ▼
用户输入验证码
    │
POST /login/phone {phone, code, role:"elder"}
    │
    ▼
返回 TokenResponse ──→ 存储 token
```

### 5.3 家庭绑定流程

```
子女端已登录
    │
输入老人手机号
    │
POST /bind-family?child_id=xxx {elder_phone:"138..."}
    │
    ▼
绑定成功 ──→ 子女端显示老人信息
             老人端"我的家人"列表同步更新
```

### 5.4 用药确认与积分流程

```
服药时间到（Schedule.time_of_day）
    │
老人端 APP 发送推送提醒
    │
老人点击"已服药"
    │
POST /confirm {medication_id, schedule_id}
    │
    ├── 写入 MedicationLog（台账）
    ├── remaining_quantity -= dosage_taken
    └── total_points += 10
         │
         ▼
累计连续天数（streak）增加
切换日期未用药则 streak 归零
```

### 5.5 积分兑换流程

```
老人浏览商品（GET /products）
    │
选择商品 → 确认兑换
    │
POST /redeem?elder_id=xxx&product_id=xxx
    │
    ├── 校验积分充足 && stock > 0
    ├── 扣除积分 → 库存减 1
    ├── 创建兑换订单（status: pending）
    └── 返回兑换成功
```

---

## 6. 错误码说明

### 6.1 通用错误码

| HTTP 状态码 | code | 说明 |
|---|---|---|
| 200 | — | 请求成功 |
| 400 | BAD_REQUEST | 请求参数错误（缺少必填字段、格式错误等） |
| 401 | UNAUTHORIZED | Token 无效或已过期 |
| 403 | FORBIDDEN | 无权限访问（如非子女执行审核） |
| 404 | NOT_FOUND | 资源不存在（药品/用户/商品等） |
| 409 | CONFLICT | 资源冲突（如重复绑定、积分不足） |
| 422 | VALIDATION_ERROR | 请求体验证失败 |
| 429 | TOO_MANY_REQUESTS | 请求频率过高 |
| 500 | INTERNAL_ERROR | 服务器内部错误 |

### 6.2 业务错误响应格式

```json
{
  "detail": "描述性错误信息"
}
```

### 6.3 常见业务错误场景

| 场景 | HTTP 状态码 | detail |
|---|---|---|
| Token 缺失 | 401 | "无效的认证凭据" |
| Token 已过期 | 401 | "Token 已过期，请重新登录" |
| 手机号未注册 | 404 | "该手机号尚未注册" |
| 绑定重复 | 409 | "该老人已被其他子女绑定" |
| 老人不存在 | 404 | "老人用户不存在" |
| 药品不属于该老人 | 403 | "无权操作此药品" |
| 积分不足 | 409 | "积分不足，当前积分：xxx，需要：xxx" |
| 商品库存不足 | 409 | "商品库存不足" |
| 审核操作非法 | 400 | "审核动作无效，请使用 approve 或 reject" |
| 药品非 pending 状态 | 400 | "当前状态不可审核" |
| 验证码错误 | 400 | "验证码错误" |
| code 已过期 | 400 | "登录凭证已过期，请重新获取" |

---

## 7. 附录：枚举与状态流转

### 7.1 药品分类枚举

| 分类 | 值 | 说明 | 特有剂型字段 |
|---|---|---|---|
| 口服药 | `oral` | 口服摄入 | `oral_form` |
| 外用药 | `external` | 外用涂抹/喷洒/贴敷 | `external_form` |
| 注射剂 | `injection` | 注射给药 | `injection_form` |
| 保健品 | `supplement` | 营养补充 | 无 |

### 7.2 剂型枚举

**口服药剂型 (`oral_form`)**

| 值 | 说明 |
|---|---|
| `tablet` | 片剂 |
| `capsule` | 胶囊 |
| `granule` | 颗粒剂 |
| `oral_liquid` | 口服液 |
| `decoction` | 汤剂 |

**外用剂型 (`external_form`)**

| 值 | 说明 |
|---|---|
| `ointment` | 软膏 |
| `spray` | 喷雾 |
| `drops` | 滴剂 |
| `patch` | 贴剂 |
| `iodophor` | 碘伏 |
| `lotion` | 洗剂 |

**注射剂型 (`injection_form`)**

| 值 | 说明 |
|---|---|
| `insulin` | 胰岛素 |
| `subcutaneous` | 皮下注射 |
| `long_acting` | 长效注射 |
| `infusion` | 输液/静脉滴注 |

### 7.3 审核状态流转图

```
            +---------+
            | pending | ◄────┐
            +----+----+      │
                 │           │
          ┌──────┴──────┐   │
          ▼             ▼   │
      +----------+  +--------+---+
      | approved |  |  rejected  │
      +----------+  +-----+------+
                          │
                    修改后提交审核
                          │
                          └────────► pending
```

### 7.4 商品分类

| 值 | 说明 |
|---|---|
| `daily` | 日用品（老花镜、保温杯等） |
| `health` | 健康用品（血压计、血糖仪等） |
| `entertainment` | 娱乐休闲（棋牌、书籍等） |

### 7.5 兑换订单状态

| 值 | 说明 |
|---|---|
| `pending` | 待发货 |
| `shipped` | 已发货 |
| `completed` | 已完成 |
| `cancelled` | 已取消 |

---

> **文档维护说明**
>
> - 本文档对应 API v0.1.0，后续版本更新请同步更新本文档。
> - 如有接口变更，请在 PR 中同时更新 API 文档。
> - 前端团队建议使用 Postman / Hoppscotch 导入本文档示例进行联调。
