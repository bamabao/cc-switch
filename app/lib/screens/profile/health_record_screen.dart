import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class HealthRecordScreen extends StatefulWidget {
  const HealthRecordScreen({super.key});

  @override
  State<HealthRecordScreen> createState() => _HealthRecordScreenState();
}

class _HealthRecordScreenState extends State<HealthRecordScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await _api.getMe();
      int? points, streak, longestStreak;
      try {
        final pts = await _api.get('${ApiConfig.points}/profile?elder_id=${user.id}');
        points = pts['total_points'] as int?;
        streak = pts['current_streak'] as int?;
        longestStreak = pts['longest_streak'] as int?;
      } catch (_) { points = user.totalPoints; streak = user.currentStreak; longestStreak = user.longestStreak; }
      if (!mounted) return;
      setState(() {
        _profile = {'points': points, 'streak': streak, 'longestStreak': longestStreak, 'name': user.name};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('健康档案')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    child: Column(children: [
                      const Text('📊 用药打卡统计', style: TextStyle(fontSize: AppTheme.titleLarge, fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppTheme.spacingLg),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _statItem('累计积分', '${_profile?['points'] ?? 0}', Icons.star, AppTheme.warningColor),
                        _statItem('连续打卡', '${_profile?['streak'] ?? 0} 天', Icons.local_fire_department, AppTheme.dangerColor),
                        _statItem('最长记录', '${_profile?['longestStreak'] ?? 0} 天', Icons.emoji_events, AppTheme.primaryColor),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('📋 健康提醒', style: TextStyle(fontSize: AppTheme.titleLarge, fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppTheme.spacingMd),
                      _tipItem(Icons.medication, '遵医嘱按时服药，漏服不要双倍补吃'),
                      _tipItem(Icons.water_drop, '每天喝足 8 杯水'),
                      _tipItem(Icons.directions_walk, '适当活动，饭后散步 30 分钟'),
                      _tipItem(Icons.bedtime, '保证充足睡眠，早睡早起'),
                    ]),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(children: [
      Container(width: 48, height: 48,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: AppTheme.titleLarge, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary)),
    ]);
  }

  Widget _tipItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 24, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: AppTheme.bodyLarge))),
      ]),
    );
  }
}
