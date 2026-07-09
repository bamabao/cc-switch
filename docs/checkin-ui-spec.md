# 爸妈宝服药打卡 UI 交互设计文档

> 方案：**独立卡片竖排款（王总方案2）**
> 状态：待开发评审
> 适用版本：v3.4+

---

## 目录

1. [改动概述](#1-改动概述)
2. [卡片布局规范](#2-卡片布局规范)
3. [多时段布局示例](#3-多时段布局示例)
4. [交互流程](#4-交互流程)
5. [首页顶部文案改动](#5-首页顶部文案改动)
6. [验收标准清单](#6-验收标准清单)

---

## 1. 改动概述

### 1.1 「今日用药」区域整体变更

| 项目 | 当前状态 | 改后状态 |
|---|---|---|
| 首页「今日用药」展示 | 每张卡片一个按钮 → 点击打卡第一个未打卡时段 | **每张卡片罗列该药所有时段**，每个时段独立打卡按钮，点击各自独立变换红/绿 |
| 卡片组件 | `MedicineCheckinCard` 单行左中右（按钮+药名+箭头） | **竖向扩展**，顶部标题行 + 下方堆叠 N 个时段行（每行独立打卡按钮） |
| 打卡按钮数量 | 每药 1 个 | 每药 N 个（N = 该药每日服用次数） |
| 顶部统计 | 仅「今天有 X 种药需要服用」 | 增加「今日共 X 种药品、剩余 X 次待服用」小字 |

### 1.2 不受影响的部分

- 语音快捷入口卡片（保持不变）
- 用药记录入口卡片（保持不变）
- 预警信息区域（保持不变）
- 底部全部药品/添加药品按钮（保持不变）
- 全局主题色、字号规范（保持不变）
- `ClayCheckinButton` 组件**内部逻辑**（保持不变）— 复用其状态色、动画、3D 样式

---

## 2. 卡片布局规范

### 2.1 整体结构（纵剖面）

```
┌─────────────────────────────────────┐  ← 圆角 R=20（AppTheme.radiusCard）
│                                     │
│  ┌──────┐  ┌─────────────────┐  ┌─┐ │  ← 第 1 行：标题行（固定高度 72~80px）
│  │ ○92  │  │ 阿莫西林胶囊     │  │>│ │       左侧圆形打卡按钮→ 中间药名(28px Bold)
│  │ btn  │  │ 1粒 · 08:00      │  │ │ │       剂量+首时段(22px灰) → 右侧箭头
│  └──────┘  └─────────────────┘  └─┘ │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │  ← 分隔线/间距 1px dashed line(可选)
│  ┌──────┐  ┌─────────────────┐      │  ← 第 2 行：时段行（如果该药有多个时段）
│  │ ○92  │  │ 20:00           │      │       打卡按钮(72px) + 时段时间文案(28px)
│  │ btn  │  │ 1粒             │      │       无右侧箭头
│  └──────┘  └─────────────────┘      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │  ← 分隔线/间距（更多时段递增）
│  ┌──────┐  ┌─────────────────┐      │  ← 第 3 行（如果有）
│  │ ○92  │  │ 睡前(22:00)     │      │
│  │ btn  │  │ 2粒             │      │
│  └──────┘  └─────────────────┘      │
│                                     │
│  卡内填充 bottom: 12px              │
└─────────────────────────────────────┘
│← 外边距 16px (父容器 spacingMd) →│
│← 左右 padding 16px              →│
```

### 2.2 各部分像素参考值

| 元素 | 尺寸/值 | 代码来源 |
|---|---|---|
| 卡片圆角 | **20px** | `AppTheme.radiusCard`（已定义） |
| 卡片背景色 | `#F2F7F0` | `AppTheme.cardColor`（已定义） |
| 卡片外边距（上下） | **8px** / 16px | 父容器 `Padding.only(bottom: AppTheme.spacingSm)` |
| 卡片阴影 | `AppTheme.shadowCard` | 弥散阴影 `blur:20, offset:0,8, alpha:0.08` |
| 卡片内边距（左右） | **16px** | `EdgeInsets.symmetric(horizontal: 16, vertical: 12)` |
| 卡片内边距（上下） | **12px** | — |
| 卡片内标题行固定高 | **72px** | `Row` + `crossAxisAlignment: center` + 固定高度 |
| — | — | — |
| **打卡按钮** | | |
| 按钮直径 | **72px** | `ClayCheckinButton`（已实现） |
| 触控外扩 | **+10px 四周** | `Padding.all(10)`（已实现） |
| 有效热区 | **92px × 92px** | 72+10×2（已实现） |
| 未服药颜色 | `#F87670` | 低饱和珊瑚红（已实现） |
| 已打卡颜色 | `#59C992` | 护眼薄荷绿（已实现） |
| 按钮圆角 | 圆形 50% | `BoxShape.circle`（已实现） |
| 3D 径向渐变 | 左上亮→中间主色→右下暗 | `RadialGradient center:-0.3,-0.3 radius:0.8`（已实现） |
| 浮雕边界 | 白色 2px, alpha:0.3 | `Border.all`（已实现） |
| 按钮阴影（3层） | 上高光(-2,-2) + 下沉(2,4) + 内缩(0,2,-1) | `boxShadow`（已实现） |
| 对勾图标 | 白色 `Icons.check`, **size:36** | `Icon(Icons.check, color: Colors.white, size: 36)`（已实现） |
| 对勾图标是否**黏土彩色** | 沿用现有白色，如需彩色黏土风格需新增自定义绘制 | 见下文 **§ 黏土对勾图标改造说明** |
| — | — | — |
| **药品名称** | | |
| 字号 | **28px** (Bold) | `fontSize: 28, fontWeight: FontWeight.bold` |
| 颜色 | `#3A4437` | `AppTheme.textPrimary` |
| 最多行 | 1行，超出省略 | `maxLines: 1, overflow: TextOverflow.ellipsis` |
| — | — | — |
| **剂量/时段小字** | | |
| 字号 | **22px** | `fontSize: 22` |
| 颜色 | `#616161` | `AppTheme.textSecondary` |
| — | — | — |
| **右侧导航箭头** | | |
| 图标 | `Icons.chevron_right` | |
| 尺寸 | **32px** | `size: 32` |
| 颜色 | `#616161` | `AppTheme.textSecondary` |
| 显示位置 | **仅标题行显示** | 下方各时段行不显示箭头 |
| — | — | — |
| **各时段行之间** | | |
| 间距 | **8px** | `SizedBox(height: spacingSm)` |
| 分隔线（按需） | 浅灰虚线 1px, `#E0E0E0`, margin:左右各 40px | 可选，便于视觉分区 |
| — | — | — |
| **整张卡片最小高度** | 标题行(72) + 上下padding(12×2) = **~96px（1个时段）** | |
| | 标题行(72) + 时段行(72) + 间距(8) + padding(12×2) = **~176px（2个时段）** | |
| | 每增一时段 +80px | |

### 2.3 ClayCheckinButton 现有实现确认

以下参数已在 `ClayCheckinButton` 中实现，**不需要改动**：

| 特性 | 当前值 |
|---|---|
| 三段式缩放动画 | 1.0 → 0.92 → 1.06 → 1.0, 总时长 500ms |
| 动画曲线 | `CurvedAnimation(parent: _controller, curve: Curves.easeInOut)` |
| 状态色切换时长 | `AnimatedContainer` 250ms |
| 颜色过渡曲线 | `Curves.easeOut` |
| 触控震动反馈 | `HapticFeedback.lightImpact()` |
| 点击行为 | `GestureDetector` + `HitTestBehavior.opaque` |

### 2.4 黏土对勾图标改造说明（可选）

当前对勾使用 `Icons.check`（标准 Material 图标，纯白）。如王总要**彩色黏土风格对勾**，有两种方案：

**方案 A：使用 `clay_icons` 现有体系（推荐）**
在 `C:\bamabao\app\lib\widgets\clay_icons\painters\` 下新增自定义绘制，用 `CustomPainter` 绘制：
- 加粗右向勾（3~4px 描边）
- 顶部内高光（白色半透明）
- 底部小阴影（黑色微透）
- 替换 `ClayCheckinButton` 中的 `Icon(Icons.check)` 为 `CustomPaint`

**方案 B：绘制为独立小卡片嵌入**
将对勾做成独立黏土小徽章，嵌在按钮右下方——但会打破按钮圆形完整性，不推荐。

**建议：** 先沿用当前 `Icons.check` 纯白对勾（已集成在 3D 按钮内），视觉融入度够。后续迭代再升级为黏土绘制版。

---

## 3. 多时段布局示例

### 3.1 双时段示例（阿莫西林胶囊 — 早8:00、晚20:00）

```
┌────────────────────────────────────────┐
│                                        │
│  ┌──────┐  ┌───────────────────┐  ┌─┐  │  ← 标题行（红色按钮=待打卡）
│  │  ○   │  │ 阿莫西林胶囊       │  │>│  │     按钮红底(待服用)
│  │ 红   │  │ 1粒 · 08:00 / 20:00│  │ │  │     小字合并显示两个时段
│  └──────┘  └───────────────────┘  └─┘  │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │  ← 分隔线（dashed 1px #E0E0E0）
│  ┌──────┐  ┌───────────────────┐      │  ← 时段行1：08:00
│  │  ✅  │  │ 08:00             │      │     按钮已变绿(已打卡)
│  │  绿  │  │ 1粒 ✅            │      │     剂量+状态说明
│  └──────┘  └───────────────────┘      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  ┌──────┐  ┌───────────────────┐      │  ← 时段行2：20:00
│  │  ○   │  │ 20:00             │      │     按钮红底(待服用)
│  │ 红   │  │ 1粒               │      │
│  └──────┘  └───────────────────┘      │
│                                        │
└────────────────────────────────────────┘
```

**解读：**
- 标题行：`isChecked` = `false`（因为尚未全部打完）→ 按钮显示红色。但**实际上**标题行按钮应**禁用点击**，只作为概览状态，由各时段行按钮执行打卡操作。
- 时段行1已打卡 → 绿色 + 白勾
- 时段行2未打卡 → 红色（无勾）
- 点击时段行2后，该行变绿色；全部打卡后，标题行按钮自动变为绿色

### 3.2 三时段示例（二甲双胍缓释片 — 早7:00、午12:00、晚18:00）

```
┌────────────────────────────────────────┐
│                                        │
│  ┌──────┐  ┌───────────────────┐  ┌─┐  │  ← 标题行（已部分打卡 → 仍红）
│  │  ○   │  │ 二甲双胍缓释片     │  │>│  │     剂量: 0.5g/次
│  │ 红   │  │ 0.5g · 早/午/晚    │  │ │  │
│  └──────┘  └───────────────────┘  └─┘  │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  ┌──────┐  ┌───────────────────┐      │  ← 早7:00（已打卡）
│  │  ✅  │  │ 07:00             │      │
│  │  绿  │  │ 0.5g              │      │
│  └──────┘  └───────────────────┘      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  ┌──────┐  ┌───────────────────┐      │  ← 午12:00（未打卡）
│  │  ○   │  │ 12:00             │      │
│  │ 红   │  │ 0.5g              │      │
│  └──────┘  └───────────────────┘      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  ┌──────┐  ┌───────────────────┐      │  ← 晚18:00（未打卡）
│  │  ○   │  │ 18:00             │      │
│  │ 红   │  │ 0.5g              │      │
│  └──────┘  └───────────────────┘      │
│                                        │
└────────────────────────────────────────┘
```

**解读：**
- 用户只打卡了早7:00，中午/晚上未打→标题行按钮仍红
- 剩余 2 次待服用
- 点击中午行→该行变绿；再点晚上行→全都绿→标题行按钮也变绿

### 3.3 标题行按钮交互规则

| 条件 | 标题行按钮显示 | 标题行按钮可点击？ |
|---|---|---|
| 所有时段已打卡 | ✅ 绿色 | ❌ 禁用（无操作） |
| 部分已打卡 | 🔴 红色 | ❌ 禁用（无操作） |
| 全部未打卡 | 🔴 红色 | ❌ 禁用（无操作） |

> **设计理由：** 标题行按钮仅作为「整体状态标识」，不响应点击。具体打卡/撤销操作在各时段行上完成。这样避免交互歧义（"点击标题行按钮到底打卡哪个时段？"）。如果需要快速打卡全部，可以后续在左下角加"一键全部打卡"按钮。

---

## 4. 交互流程

### 4.1 打卡流程

```
 ┌─────────────────────────────────────┐
 │        点击前（未打卡状态）           │
 │  ○ 按钮：红色 #F87670               │
 │  无勾                               │
 │  3D黏土质感（径向渐变 + 浮雕 + 阴影）│
 └──────────────┬──────────────────────┘
                │  用户手指按下
                ▼
 ┌─────────────────────────────────────┐
 │        点击动画（~500ms）            │
 │  step1: 缩放 1.0 → 0.92 (15%)      │  ← 按压反馈，按钮轻微缩小
 │  step2: 缩放 0.92 → 1.06 (25%)     │  ← 弹起超调，黏土回弹感
 │  step3: 缩放 1.06 → 1.0 (60%)      │  ← 归位
 │  同时：HapticFeedback.lightImpact() │  ← 震动反馈
 │  同时：触发后端 API 请求             │
 └──────────────┬──────────────────────┘
                │  动画结束，状态更新
                ▼
 ┌─────────────────────────────────────┐
 │        点击后（已打卡状态）           │
 │  ✅ 按钮：绿色 #59C992              │
 │  白色对勾 Icons.check size=36       │
 │  AnimatedContainer 250ms 完成颜色过渡│
 │  3D黏土质感不变（色值变化）           │
 │  底部文案刷新（如"剩余 X 次"减少）    │
 └─────────────────────────────────────┘
```

### 4.2 撤销打卡流程（再次点击已打卡的绿色按钮）

```
 ┌─────────────────────────────────────┐
 │        点击前（已打卡状态）           │
 │  ✅ 按钮：绿色 #59C992 + 白勾       │
 └──────────────┬──────────────────────┘
                │  用户再次点击同一按钮
                ▼
 ┌─────────────────────────────────────┐
 │         动画（500ms，同打卡流程）      │
 │  step1: 1.0 → 0.92                  │
 │  step2: 0.92 → 1.06                 │
 │  step3: 1.06 → 1.0                  │
 │  HapticFeedback.lightImpact()        │
 │  触发撤销 API 请求                    │
 └──────────────┬──────────────────────┘
                │  撤销成功
                ▼
 ┌─────────────────────────────────────┐
 │        点击后（未打卡状态）           │
 │  ○ 按钮：红色 #F87670               │
 │  无勾                               │
 │  3D黏土质感不变                      │
 │  底部文案刷新（"剩余 X 次"增加）      │
 │  标题行按钮保持红（因还有未打卡时段）   │
 └─────────────────────────────────────┘
```

### 4.3 全时段打完后的状态变化

```
 ┌─────────────────────────────────────┐
 │  最后一时段打卡成功                    │
 │                                      │
 │  this schedule → ✅ 绿勾             │
 │  检测该药所有 schedules 全部 checked  │
 │  → 标题行按钮也变 ❌→✅(绿)          │
 │  → 首页顶部"剩余 X 次"减 1            │
 │  → 如果所有药全部打完：                │
 │     "剩余 0 次待服用" 显示全绿状态      │
 └─────────────────────────────────────┘
```

### 4.4 数据流（API 时序）

```
用户点击时段按钮
    │
    ├─ 本地乐观更新：
    │   immediate: 按钮变色 + 勾出现/消失
    │   (减少等待感，老年人不耐 Loading)
    │
    ├─ API 调用（并行）：
    │   POST /api/v1/checkin/medication/:id/schedule/:scheduleId
    │   或
    │   POST /api/v1/checkin/medication/:id/undo
    │
    ├─ 成功：
    │   → 保持本地状态，刷新首页顶部统计
    │   → 更新该 card 的 checkedSlots / totalSlots
    │   → 触发标题行按钮状态重算
    │
    └─ 失败：
        → 回滚至点击前状态（按钮恢复原色）
        → 弹出 SnackBar：打卡失败/撤销失败 + 错误信息（2秒浮动）
        → 不阻塞后续操作
```

### 4.5 防误触/安全措施

| 措施 | 实现方式 |
|---|---|
| 点击冷却 | 同一按钮 500ms 内只响应一次（利用动画时长做天然冷却） |
| 在动画中锁定 | 动画播放期间，`GestureDetector` 可通过 `_animating = true` 判断屏蔽二次点击 |
| 错误回滚 | API 失败时自动回滚 UI 状态（见 4.4） |
| 撤销不设限 | 允许随时撤销重新打卡，不用确认弹窗（适老简化） |

---

## 5. 首页顶部文案改动

### 5.1 现有首页顶部代码（`home_screen.dart`）

```dart
// 当前文案：
_medicationCount > 0
  ? '今天有 $_pendingCount 种药需要服用'
  : '还没有添加药品哦'
```

### 5.2 改后文案

```dart
// 内部维护两个变量：
int _totalMedicationTypes;  // 今日有 X 种药品（有安排的药品数）
int _remainingCheckinCount; // 剩余 X 次待服用

// 文案1：保留大字
_medicationCount > 0
  ? '今天有 $_totalMedicationTypes 种药需要服用'
  : '还没有添加药品哦'

// 文案2：新增小字（紧接在下方，间距 4px）
// style: fontSize: 22, color: AppTheme.textSecondary
// 只在有药品时显示
_medicationCount > 0
  ? '今日共 $_totalMedicationTypes 种药品、剩余 $_remainingCheckinCount 次待服用'
  : ''
```

### 5.3 与 API 数据的对应关系

| 变量 | 数据来源 | 说明 |
|---|---|---|
| `_totalMedicationTypes` | `checkinResult['items'].length` | 今日有安排的药品种类数 |
| `_remainingCheckinCount` | `checkinResult['total_pending']` | 所有药品累计未打卡次数 |

### 5.4 刷新机制

- 每次任一卡片打卡/撤销成功后，`_loadData()` 重新拉取 `getTodayCheckin()`
- `_pendingCount`（用 `_remainingCheckinCount` 代替）自动更新
- 首页 `setState` 后「剩余 X 次」实时刷新

```
打卡前： 今天有 3 种药需要服用
         今日共 3 种药品、剩余 5 次待服用
         ─────────────────
         08:00 阿莫西林[未] ✓ 点击打卡
         ─────────────────
         → API 成功返回
         ─────────────────
         今日共 3 种药品、剩余 4 次待服用  ← 实时更新
```

---

## 6. 验收标准清单

### 6.1 视觉验收

| # | 检查项 | 预期值 | 通过标准 |
|---|--------|--------|---------|
| V1 | 卡片圆角 | 20px | 截图测量四角圆滑无硬角 |
| V2 | 卡片阴影 | `AppTheme.shadowCard` | 柔和弥散，卡片有悬浮感 |
| V3 | 卡片背景色 | `#F2F7F0` | 哑光暖白，非纯白 |
| V4 | 按钮直径 | 72px（触控区 92px） | 测量 widget 尺寸 |
| V5 | 按钮颜色（未打卡） | `#F87670` | 低饱和珊瑚红，不刺眼 |
| V6 | 按钮颜色（已打卡） | `#59C992` | 护眼薄荷绿 |
| V7 | 按钮 3D 质感 | 径向渐变 + 浮雕白边 + 3层阴影 | 视觉上像从卡片上"凸起" |
| V8 | 对勾图标（已打卡） | 白色 `Icons.check` size:36 | 居中清晰可见 |
| V9 | 药品名称字号/颜色 | 28px Bold / `#3A4437` | 1行超出缩略 |
| V10 | 剂量小字字号/颜色 | 22px / `#616161` | 比药名明显小 |
| V11 | 右侧箭头 | `Icons.chevron_right` size:32 | 仅标题行显示 |
| V12 | 时段行之间的分隔 | 8px 间距（可选虚线） | 视觉易区分各时段 |
| V13 | 首页顶部大字 | 「今天有 X 种药需要服用」| 保留原有 |
| V14 | 首页顶部小字 | 「今日共 X 种药品、剩余 X 次待服用」| 字号 22px，灰色 |
| V15 | 整体适老化 | 按钮≥80px、文字≥20px | 符合 UI 设计规范 |

### 6.2 交互验收

| # | 检查项 | 预期值 | 通过标准 |
|---|--------|--------|---------|
| I1 | 打卡按钮点击动画 | 三段式 1.0→0.92→1.06→1.0 @500ms | 录制慢动作检查缩放轨迹 |
| I2 | 按钮颜色过渡 | `AnimatedContainer` 250ms `Curves.easeOut` | 色彩渐变平滑，无闪变 |
| I3 | 按钮状态切换 | 红色→绿色（打卡）绿色→红色（撤销） | 状态一一对应 |
| I4 | 震动反馈 | `HapticFeedback.lightImpact()` | 点击时有微震动（真机） |
| I5 | 标题行按钮不变色 | 始终仅作状态标识，不可点击 | 点击无反应 |
| I6 | 点击冷却 | 同按钮 500ms 内拒绝二次触发 | 快速连按只触发一次 |
| I7 | 动画锁定 | 动画播放中拒接新点击 | 设置 `_animating` 锁 |
| I8 | 乐观更新 | 点击→立即变色，不等待 API | 体验无感知延迟 |
| I9 | API 失败回滚 | 按钮回退点击前颜色 + 对勾 | 网络断开时测试 |
| I10 | API 失败提示 | SnackBar 浮动 2s | 必现错误文案 |
| I11 | 撤销流程 | 绿色→动画→红色 | 同入口无二次确认 |
| I12 | 全部打完联动 | 标题行按钮自动变绿 | 全部打卡验证 |
| I13 | 部分打完联动 | 标题行按钮保持红 | 只打一个时验证 |

### 6.3 数据一致性验收

| # | 检查项 | 预期值 | 通过标准 |
|---|--------|--------|---------|
| D1 | 首页顶部总药品数 | = 卡片张数 | 计数一致性 |
| D2 | 首页顶部剩余次数 | = 所有卡片未打卡数之和 | 逐卡累加验证 |
| D3 | 打卡后剩余次数 | 减 1 | 验证减少 |
| D4 | 撤销后剩余次数 | 加 1 | 验证增加 |
| D5 | 全打完后剩余次数 | 0 | 验证归零 |
| D6 | 跨天重置 | 新一天所有按钮恢复红色 | 验证重置 |
| D7 | 单药打完统计 | 标题行按钮变绿 | 验证变色 |
| D8 | 数据持久化 | 刷新/关闭重开→打卡状态保留 | 验证 API 持久 |
| D9 | 打卡/撤销并发 | 快速连续打卡两个时段→两请求均成功 | 验证并行请求 |
| D10 | API 返回结构 | `{'items': [...], 'total_pending': N}` | 接口契约验证 |

### 6.4 边界情况验收

| # | 场景 | 预期行为 |
|---|------|---------|
| E1 | 某药无时间段 | 不显示该药卡片（或显示「暂未设定时间」） |
| E2 | 某药只有 1 个时段 | 标题行显示药名+该时段，下方无附加时段行 |
| E3 | 某药有 5+ 个时段 | 卡片高度正常增长，所有时段均可滚动 |
| E4 | 药品名超长 | 最多 1 行 + 省略号 |
| E5 | 时间段到达后自动刷新状态 | 建议：进入首页/下拉刷新时重新拉取 |
| E6 | 网络断开 | 乐观更新后应有失败回滚提示（见 I9） |
| E7 | 多药品样式一致性 | 所有卡片间距、对齐、圆角一致 |

---

## 附录 A：代码改造建议

### A.1 `MedicineCheckinCard` 重构方向

当前组件是 `StatelessWidget`，单时段单按钮。改造后应为 `StatefulWidget` 或由父组件传入完整 schedules 数组，内部循环渲染多个时段行。

**建议改造方案：**

```dart
class MedicineCheckinCard extends StatefulWidget {
  final int medicationId;
  final String medicationName;
  final String dosagePerTake;  // "1粒"
  final String unit;
  final List<ScheduleItem> schedules;  // 所有时段
  final int checkedSlots;
  final int totalSlots;
  final VoidCallback? onDetailTap;
  final Function(int scheduleIndex)? onCheckinTap;  // 带索引的回调

  // ...
}

class _MedicineCheckinCardState extends State<MedicineCheckinCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        children: [
          // ── 标题行（固定结构） ──
          _buildHeaderRow(),
          // ── 各时段行 ──
          ...widget.schedules.asMap().entries.map(
            (entry) => _buildScheduleRow(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    // 标题行：ClayCheckinButton(disabled) + 药名+剂量+首时段 + 箭头
    // 按钮：allChecked ? 绿 : 红；禁用点击
    // dose+time 显示所有时段的串联文案 "1粒 · 08:00 / 20:00"
  }

  Widget _buildScheduleRow(int index, ScheduleItem schedule) {
    // 时段行：ClayCheckinButton(active) + 时段时间 + 剂量
    // onTap → widget.onCheckinTap(index)
    // 无右侧箭头
  }
}
```

### A.2 `HomeScreen._buildCheckinCards()` 改造点

```dart
// 当前（v3.3）：
// 每项只取第一个时段 → 一个按钮打全部
// 改造后：
return _checkinItems.map((item) {
  final schedules = item['schedules'] as List<dynamic>? ?? [];
  return MedicineCheckinCard(
    medicationId: item['medication_id'],
    medicationName: item['name'],
    dosagePerTake: item['dosage_per_take'],
    unit: item['unit'],
    schedules: schedules.map((s) => ScheduleItem(
      scheduleId: s['schedule_id'],
      time: s['time'],
      dosage: s['dosage'],
      checked: s['checked'],
    )).toList(),
    checkedSlots: item['checked_slots'],
    totalSlots: item['total_slots'],
    onCheckinTap: (index) => _handleCheckinTap(item, index),
    onDetailTap: () => navigateToDetail(item),
  );
}).toList();
```

### A.3 API 调用改造

当前：
```dart
// 无 scheduleIndex 传入，推测打卡第一个未打卡时段
await _api.checkinMedication(medicationId: id, elderId: 1, scheduleIndex: 0);
```

改造后应支持指定 `scheduleId`：
```dart
// 明确指定要打卡的 scheduleId
await _api.checkinSchedule(medicationId: id, scheduleId: scheduleId);
// 或保留 scheduleIndex + schedules[scheduleIndex]['schedule_id']
```

建议在 `ApiService` 中增加：
```dart
Future<void> checkinSchedule({required int medicationId, required int scheduleId});
Future<void> undoCheckin({required int medicationId, required int scheduleId});
```

---

## 附录 B：与现有组件的兼容说明

| 现有组件 | 是否需要修改 | 说明 |
|---|---|---|
| `ClayCheckinButton` | **否**（完全复用） | 状态色、阴影、径向渐变、动画全部不变 |
| `MedicineCheckinCard` | **是 - 重写** | 改造为 Column 多时段布局 |
| `HomeScreen` | **是 - 部分修改** | 顶部新增小字文案；`_buildCheckinCards` 改造 |
| `AppTheme` | **否** | 已有 `radiusCard=20`、`shadowCard` 等齐全 |
| `clay_icons/` | **可选** | 如需黏土风格对勾，需新增 CustomPainter |
| `ApiService.getTodayCheckin()` | **需确认返回值** | 确认返回 schedules 数组含 `checked` 字段 |

---

> 文档版本：v1.0
> 编写：小陈 📋
> 日期：2026-07-09
