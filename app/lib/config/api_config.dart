/// 爸妈宝 — API 配置
class ApiConfig {
  // 后端服务地址：模拟器用10.0.2.2，真机用实际IP
  // Release构建会自动切到192.168.10.3
  static const String baseUrl = 'http://192.168.10.3:8001';
  static const String apiPrefix = '/api/v1';

  // 端点 — 与后端 FastAPI 路由完全一致
  static const String health = '$apiPrefix/health';
  static const String authLogin = '$apiPrefix/auth/login/phone';
  static const String authSendSms = '$apiPrefix/auth/send-sms';
  static const String authMe = '$apiPrefix/auth/me';
  static const String authBindFamily = '$apiPrefix/auth/bind-family';
  static const String medications = '$apiPrefix/medications';
  static const String points = '$apiPrefix/points';
  static const String pointProducts = '$apiPrefix/points/products';
  static const String pointOrders = '$apiPrefix/points/orders';
  static const String reminders = '$apiPrefix/reminders';
  static const String medicationConfirm = '$apiPrefix/medications/confirm';

  // 积分兑换
  static const String redeem = '$apiPrefix/points/redeem';

  // 用户
  static const String authProfile = '$apiPrefix/auth/profile';

  // OCR识别
  static const String ocrRecognize = '$apiPrefix/ocr/recognize';

  // 紧急联系人
  static const String emergencyContacts = '$apiPrefix/emergency-contacts';
  static const String emergencyContactPrimary = '$apiPrefix/emergency-contacts/primary/phone';

  // 服药打卡
  static const String checkinToday = '$apiPrefix/medications/checkin/today';
  static const String drugSearch = '$apiPrefix/drug/search';

  // 版本更新
  static const String appVersion = '$apiPrefix/app/version';

  // AI 智能
  static const String aiAsk = '$apiPrefix/ai/ask';
  static const String aiInteraction = '$apiPrefix/ai/interaction';
  static const String aiWeeklyReport = '$apiPrefix/ai/weekly-report';

  // 医患沟通
  static const String chatSend = '$apiPrefix/chat/send';
  static const String chatHistory = '$apiPrefix/chat/history';
  static const String chatRead = '$apiPrefix/chat/read';
  static const String chatUnread = '$apiPrefix/chat/unread-count';

  // 电子处方（专家版）
  static const String prescriptionPending = '$apiPrefix/prescription/pending';
  static const String prescriptionAccept = '$apiPrefix/prescription/accept';
  static const String prescriptionReject = '$apiPrefix/prescription/reject';

  // 医院交流平台（第一期：我的医院）
  static const String hospitalMyInfo = '$apiPrefix/hospital/my-info';
}
