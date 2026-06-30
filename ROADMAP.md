/**
 * 爸妈宝 — 开发路线控制表
 * 
 * 定位：该项目根的核心文档，记录所有关键决定、依赖约束、上下文
 * 每次有进展时更新（不晚于每天一次）
 * 
 * 格式：
 *   ✅ = 已完成
 *   🔄 = 进行中
 *   ⏳ = 待办（有依赖/阻塞原因）
 *   ⛔ = 阻塞/取消
 */

## 📋 阶段目标：MVP Demo（王总决策：靠AI出Demo版）

### ✅ 已完成
- 后端 API ✅ (FastAPI, 8张表, 22端点, 54测试全绿, 运行在 192.168.10.3:8000)
- API 文档 ✅ (34KB, 21端点, 数据模型, 业务流程, 错误码)
- 语音SDK选型报告 ✅ (推荐科大讯飞: 30+方言/离线SDK/Flutter集成方案)
- UI设计规范 ✅ (适老化: 2倍字号/高对比/≥80px按钮)
- APP 32页规划 ✅
- 小程序12页规划 ✅
- 项目排期/看板/团队架构 ✅
- 营业执照OCR ✅ (岳阳市奥云科技, 法人王治国)
- 华为开发者账号资质 ✅ (执照已备)

### ✅ Flutter 环境搭建 (2026-06-29)
- Flutter SDK 3.29.2 → C:\tools\flutter
- JDK 17 (Microsoft) → C:\tools\jdk-17.0.19+10
- 项目脚手架创建完成 → C:\...\projects\爸妈宝\app
- 代码静态分析通过 ✅ (0 error, 0 warning)

### ✅ Flutter APP 核心代码 (2026-06-29)
- main.dart → 主入口 + 底部4Tab导航
- config/theme.dart → 适老化主题(2倍字号/高对比/大按钮)
- config/api_config.dart → API端点配置
- models/medication.dart → 药品/提醒/用药记录模型
- models/user.dart → 用户/积分/商品/订单模型
- services/api_service.dart → 后端API对接(登录/药品CRUD/健康检查)
- services/voice_service.dart → 语音服务(MethodChannel→讯飞SDK)
- screens/home/home_screen.dart → 首页(问候/语音入口/今日用药)
- screens/medicines/medicines_screen.dart → 药品列表
- screens/voice/voice_screen.dart → 全屏语音助手
- screens/mall/mall_screen.dart → 积分商城首页
- screens/profile/profile_screen.dart → 个人中心

### 🔄 进行中 / 待办
- Android SDK 安装 (需下载Android Studio或cmdline-tools)
- Flutter `flutter doctor` 验证
- Android APK 编译并验证
- 讯飞语音SDK调研 → 集成方案文档
- Java原生桥接代码 (Android VoicePlugin.kt)
- 华为开发者账号注册
- 服务器/域名配置

### ⏳ 后续 Sprint 1
- 药品录入/扫码页面
- 用药提醒定时器
- 服药日历页
- 积分兑换流程
- 小程序端启动

## 🔧 环境约束
- 开发机 IP: 192.168.10.3
- 后端端口: 8000
- 操作系统: Windows 11 (25H2)
- Flutter: 3.29.2
- JDK: 17.0.19 (Microsoft Build)
- Dart: 3.7.2
- 网络: 国内环境, Flutter镜像已配 (pub.flutter-io.cn / storage.flutter-io.cn)
- JDK国内下载: 通过 aka.ms 下载MS版正常

## 📞 联系方式
- 王总决策通道: 小陈 (秘书agent) 
- 小陈session: agent:secretary:openclaw-weixin:...
- 汇报频率: 有进展随时同步, 无硬性每2小时
