/// 爸妈宝 — API 配置
class ApiConfig {
  // 后端服务地址
  // 开发环境：localhost:8000
  // 生产环境：替换为实际服务器地址
  static const String baseUrl = 'https://bambao.loca.lt';
  static const String apiPrefix = '/api/v1';

  // 端点 — 与后端 FastAPI 路由完全一致
  static const String health = '$apiPrefix/health';
  static const String authLogin = '$apiPrefix/auth/login/phone';
  static const String authSendSms = '$apiPrefix/auth/send-sms';
  static const String authMe = '$apiPrefix/auth/me';
  static const String authBindFamily = '$apiPrefix/auth/bind-family';
  static const String medications = '$apiPrefix/medications';
  static const String auditRecords = '$apiPrefix/audit-records';
  static const String points = '$apiPrefix/points';
  static const String pointProducts = '$apiPrefix/points/products';
  static const String pointOrders = '$apiPrefix/points/orders';
  static const String reminders = '$apiPrefix/reminders';
  static const String medicationConfirm = '$apiPrefix/medications/confirm';

  // 积分兑换
  static const String redeem = '$apiPrefix/points/redeem';

  // 审核（静态方法）
  static String medicationSubmit(int id) => '$apiPrefix/medications/$id/submit';
  static String medicationAudit(int id) => '$apiPrefix/medications/$id/audit';

  // 用户
  static const String authProfile = '$apiPrefix/auth/profile';
}
