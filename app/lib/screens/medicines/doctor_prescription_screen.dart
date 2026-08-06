import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

/// 患者端 - 医生用药方案（专家版）接收页
class DoctorPrescriptionScreen extends StatefulWidget {
  const DoctorPrescriptionScreen({super.key});

  @override
  State<DoctorPrescriptionScreen> createState() => _DoctorPrescriptionScreenState();
}

class _DoctorPrescriptionScreenState extends State<DoctorPrescriptionScreen> {
  final ApiService _api = ApiService();
  final http.Client _client = http.Client();
  List<Map<String, dynamic>> _prescriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.prescriptionPending}/1');
      final resp = await _client.get(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        setState(() => _prescriptions = (data['prescriptions'] ?? []).cast<Map<String, dynamic>>());
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _accept(Map<String, dynamic> presc) async {
    try {
      final r = await _api.post('${ApiConfig.prescriptionAccept}/${presc['id']}', body: {});
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('接收成功', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Text(r['message'] ?? '药品和服药提醒已自动创建'),
          actions: [
            FilledButton(
              onPressed: () { Navigator.pop(ctx); _load(); },
              child: const Text('好的'),
            ),
          ],
        ),
      );
    } catch (e) {
      _toast('接收失败：$e');
    }
  }

  Future<void> _reject(Map<String, dynamic> presc) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拒绝方案'),
        content: const Text('拒绝后医生会收到通知，也可以先咨询医生再决定'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, '患者拒绝'), child: const Text('确认拒绝')),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await _api.post('${ApiConfig.prescriptionReject}/${presc['id']}?reason=$reason', body: {});
      _toast('已拒绝');
      _load();
    } catch (e) {
      _toast('操作失败：$e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👨‍⚕️ 医生的用药方案'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _prescriptions.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.inbox_outlined, size: 72, color: Colors.grey),
                        SizedBox(height: 12),
                        Center(child: Text('暂无医生发来的方案', style: TextStyle(fontSize: 16, color: AppTheme.textLightGray))),
                        SizedBox(height: 6),
                        Center(child: Text('医生开好药后，会显示在这里', style: TextStyle(fontSize: 13, color: AppTheme.textLightGray))),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: _prescriptions.map((p) => _buildCard(p)).toList(),
                    ),
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> presc) {
    final items = (presc['items'] ?? []).cast<Map<String, dynamic>>();
    final totalDays = items.isNotEmpty ? (items.first['duration_days'] ?? 7) : 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.shadowCard,
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 头部：医生信息
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    (presc['doctor_name'] as String? ?? '医').characters.first,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(presc['title'] ?? '用药方案',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      Text(
                        '${presc['doctor_name']} · ${presc['doctor_hospital'] ?? ''} · ${presc['doctor_title'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('疗程${totalDays}天',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
                ),
              ],
            ),
          ),
          // 药品列表
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.medication, size: 18, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['drug_name'] ?? '',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  '${item['dosage_per_take'] ?? 1}${item['unit'] ?? '粒'} × ${(item['times'] as List).join('、')}'
                                  '${item['meal_relation']?.isNotEmpty == true ? '（${item['meal_relation']}）' : ''}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                ),
                                if ((item['notes'] ?? '').isNotEmpty)
                                  Text('📝 ${item['notes']}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                if ((presc['summary'] ?? '').isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('💬 ${presc['summary']}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ),
              ],
            ),
          ),
          // 按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(presc),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('拒绝'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => _accept(presc),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('一键接收，自动设置提醒', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
