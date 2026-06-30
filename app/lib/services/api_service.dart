import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/medication.dart';
import '../models/user.dart';

/// 爸妈宝 — API 服务
/// 对接后端 FastAPI 服务
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;
  final _client = http.Client();

  String get baseUrl => ApiConfig.baseUrl;

  /// 获取当前 Token
  String? get token => _token;

  /// 设置认证 Token
  void setToken(String token) => _token = token;

  /// 通用 GET 请求
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    final response = await _client.get(
      uri,
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  /// 通用 POST 请求
  Future<Map<String, dynamic>> post(String endpoint,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// 请求头
  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// 处理响应
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HttpException(
      '请求失败: ${response.statusCode} ${response.body}',
      uri: Uri.parse('$baseUrl${response.request?.url.path ?? ""}'),
    );
  }

  // ─── 认证 ───

  /// 手机号登录（一期固定验证码 123456）
  Future<UserProfile> login(String phone, String code) async {
    final result = await post(ApiConfig.authLogin, body: {
      'phone': phone,
      'code': code,
    });
    _token = result['access_token'] as String?;
    return UserProfile.fromJson({...result, 'phone': phone});
  }

  /// 发送验证码（后端POST，phone在query）
  Future<String> sendSmsCode(String phone) async {
    final uri = Uri.parse('$baseUrl${ApiConfig.authSendSms}?phone=$phone');
    final headers = await _headers();
    final response = await _client.post(
      uri,
      headers: headers,
    );
    final result = _handleResponse(response);
    return result['code'] as String? ?? '123456';
  }

  /// 获取当前用户信息
  Future<UserProfile> getMe() async {
    final result = await get('${ApiConfig.authMe}?token=$_token');
    return UserProfile.fromJson(result);
  }

  // ─── 药品 ───

  /// 获取药品列表
  Future<List<Medication>> getMedications({int? elderId}) async {
    final params = <String, String>{};
    if (elderId != null) params['elder_id'] = elderId.toString();
    if (_token != null) params['token'] = _token!;

    final result = await get(ApiConfig.medications, queryParams: params);
    final list = result['items'] as List<dynamic>? ?? [];
    return list.map((e) => Medication.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 获取单个药品详情
  Future<Map<String, dynamic>> getMedication(int id, {required int elderId}) async {
    final result = await get('${ApiConfig.medications}/$id?elder_id=$elderId&token=$_token');
    return result;
  }

  /// 添加药品
  Future<Map<String, dynamic>> addMedication(Map<String, dynamic> body, {required int elderId}) async {
    final result = await post('${ApiConfig.medications}?elder_id=$elderId', body: body);
    return result;
  }

  /// 确认用药
  Future<Map<String, dynamic>> confirmMedication({
    required int medicationId,
    required int scheduleId,
    required int elderId,
    required double dosageTaken,
    String? remark,
  }) async {
    final result = await post('${ApiConfig.medications}/confirm?elder_id=$elderId', body: {
      'medication_id': medicationId,
      'schedule_id': scheduleId,
      'dosage_taken': dosageTaken,
      'remark': remark ?? '',
    });
    return result;
  }

  /// 提交审核
  Future<Map<String, dynamic>> submitMedication(int medicationId) async {
    return await post(ApiConfig.medicationSubmit(medicationId));
  }

  /// 获取用药历史
  Future<Map<String, dynamic>> getMedicationLogs({
    required int elderId,
    int? medicationId,
    int days = 7,
  }) async {
    final params = <String, String>{
      'elder_id': elderId.toString(),
      'days': days.toString(),
    };
    if (medicationId != null) params['medication_id'] = medicationId.toString();
    if (_token != null) params['token'] = _token!;
    return await get('${ApiConfig.medications}/logs/history', queryParams: params);
  }

  // ─── 健康检查 ───

  Future<bool> healthCheck() async {
    try {
      final result = await get(ApiConfig.health);
      return result['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }
}
