import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../chat/patient_chat_screen.dart';
import '../medicines/doctor_prescription_screen.dart';
import '../profile/health_metric_screen.dart';

/// 我的医院 — 医院交流平台首页（第一期）
/// 展示：医院信息 / 医生列表 / 在线咨询 / 健康档案共享 / 知情同意
class HospitalCenterScreen extends StatefulWidget {
  const HospitalCenterScreen({super.key});

  @override
  State<HospitalCenterScreen> createState() => _HospitalCenterScreenState();
}

class _HospitalCenterScreenState extends State<HospitalCenterScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _hospitals = [];
  int _unread = 0;
  bool _shared = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.get('${ApiConfig.hospitalMyInfo}?elder_id=1');
      if (mounted) {
        setState(() {
          _hospitals = (r['hospitals'] as List<dynamic>?) ?? [];
          _unread = (r['unread'] as int?) ?? 0;
          _shared = (r['shared'] as bool?) ?? true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('我的医院', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hospitals.isEmpty
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_hospital_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('暂未绑定医院', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('到院就诊时，可向医生出示健康档案\n完成绑定后即可在线咨询', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final h = _hospitals.first as Map<String, dynamic>;
    final doctors = (h['doctors'] as List<dynamic>?) ?? [];
    final departments = (h['departments'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 医院信息卡
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.local_hospital, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${h['name'] ?? '医院'}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('${departments.length}个科室 · ${doctors.length}位医生 · 健康档案已共享',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('持证医疗机构 · 医生资质已核验',
                            style: TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 功能入口
          _buildFeatureRow(context, doctors),

          const SizedBox(height: 16),

          // 医生列表
          _buildSectionTitle('👨‍⚕️ 我的医生（${doctors.length}）'),
          const SizedBox(height: 8),
          ...doctors.map((d) => _buildDoctorItem(context, d as Map<String, dynamic>)),

          const SizedBox(height: 16),

          // 健康档案共享
          _buildSectionTitle('📋 健康档案共享'),
          const SizedBox(height: 8),
          _buildHealthCard(context),

          const SizedBox(height: 16),

          // 知情同意说明
          _buildSectionTitle('📜 知情与免责'),
          const SizedBox(height: 8),
          _buildConsentCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, List<dynamic> doctors) {
    final primaryDoctor = doctors.isNotEmpty ? doctors.first as Map<String, dynamic> : null;
    return Row(
      children: [
        Expanded(
          child: _featureCard(
            icon: Icons.chat_bubble_outline,
            label: '在线咨询',
            badge: _unread > 0 ? '$_unread' : null,
            onTap: () async {
              if (primaryDoctor == null) return;
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => PatientChatScreen(
                  doctorId: (primaryDoctor['id'] as num?)?.toInt() ?? 1,
                  patientId: 1,
                  doctorName: (primaryDoctor['real_name'] as String?) ?? '医生',
                ),
              ));
              _load();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _featureCard(
            icon: Icons.monitor_heart_outlined,
            label: '健康数据',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HealthMetricScreen())),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _featureCard(
            icon: Icons.assignment_outlined,
            label: '专家方案',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DoctorPrescriptionScreen())),
          ),
        ),
      ],
    );
  }

  Widget _featureCard({
    required IconData icon,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.shadowCard,
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 30, color: AppTheme.primaryColor),
                if (badge != null)
                  Positioned(
                    right: -14, top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppTheme.dangerColor, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(badge,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary));
  }

  Widget _buildDoctorItem(BuildContext context, Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
            child: Text((d['real_name'] as String? ?? '医')[0],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${d['real_name'] ?? '医生'}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${d['title'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${d['department'] ?? '综合'}科 · 执业证书号 ****${d['practice_no'] ?? ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if ((d['intro'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${d['intro']}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_outlined, color: AppTheme.primaryColor),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => PatientChatScreen(
                  doctorId: (d['id'] as num?)?.toInt() ?? 1,
                  patientId: 1,
                  doctorName: (d['real_name'] as String?) ?? '医生',
                ),
              ));
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('您的用药记录、血压、血糖、睡眠数据已授权共享给绑定医院',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _shared ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_shared ? '已共享' : '未共享',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: _shared ? const Color(0xFF2E7D32) : const Color(0xFFE65100))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HealthMetricScreen())),
              child: const Text('查看我的健康数据 ›',
                  style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️ 知情同意与免责声明',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF795548))),
          const SizedBox(height: 6),
          Text('• 平台提供医患沟通与健康管理工具，不提供诊疗服务\n'
              '• 医生建议仅供参考，诊断与处方请以医院线下就诊为准\n'
              '• 您的健康数据仅用于绑定医院的健康管理服务\n'
              '• 出现呼吸困难、胸痛等紧急情况，请立即拨打120',
              style: TextStyle(fontSize: 12, height: 1.7, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
