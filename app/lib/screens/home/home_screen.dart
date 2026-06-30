import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../medicines/medicines_screen.dart';
import '../medicines/record_screen.dart';
import '../voice/voice_screen.dart';
import '../profile/settings_screen.dart';

/// 首页 / Dashboard — 对接后端真实API
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  String _greeting = '早上好！';
  int _medicationCount = 0;
  int _pendingCount = 0;
  int _alertCount = 0;
  List<dynamic> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _loadData();
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 12) {
        _greeting = '早上好！';
      } else if (hour < 18) {
        _greeting = '下午好！';
      } else {
        _greeting = '晚上好！';
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final medsResult = await _api.get(ApiConfig.medications, queryParams: {
        'elder_id': '1',
      });
      final medications = medsResult['items'] as List<dynamic>? ?? [];
      final approved = medications.where((m) => m['status'] == 'approved').toList();

      final alertsResult = await _api.get('${ApiConfig.medications}/alerts', queryParams: {
        'elder_id': '1',
      });
      final alerts = alertsResult['items'] as List<dynamic>? ?? [];

      // 待审核药品
      final pendingResult = await _api.get('${ApiConfig.medications}/pending', queryParams: {
        'elder_id': '1',
      });
      final pendingList = pendingResult['items'] as List<dynamic>? ?? [];

      if (!mounted) return;
      setState(() {
        _medicationCount = approved.length;
        _pendingCount = pendingList.length;
        _alertCount = alerts.length;
        _alerts = alerts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('爸妈宝'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: '设置',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 头部问候 ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        _loading
                            ? '加载中…'
                            : _medicationCount > 0
                                ? '今天有 $_medicationCount 种药需要服用'
                                : '还没有添加药品哦',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // ── 待审核提醒 ──
              if (!_loading && _pendingCount > 0)
                Card(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  child: ListTile(
                    leading: const Icon(Icons.checklist, color: AppTheme.warningColor, size: 32),
                    title: Text('$_pendingCount 种药品待子女审核',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('子女审核通过后才能开始服药提醒哦',
                        style: TextStyle(fontSize: AppTheme.bodyMedium)),
                    trailing: const Icon(Icons.chevron_right, size: 28),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MedicinesScreen())),
                  ),
                ),

              const SizedBox(height: AppTheme.spacingMd),

              // ── 语音快捷入口 ──
              SizedBox(
                height: 120,
                child: Card(
                  color: AppTheme.primaryColor,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VoiceScreen()),
                      );
                    },
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic, size: 56, color: AppTheme.textOnDark),
                          SizedBox(width: AppTheme.spacingMd),
                          Text(
                            '对我说 "帮我看看今天的药"',
                            style: TextStyle(
                              fontSize: AppTheme.titleMedium,
                              color: AppTheme.textOnDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // ── 用药记录入口 ──
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingSm,
                  ),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(Icons.calendar_month, size: 32, color: AppTheme.secondaryColor),
                  ),
                  title: const Text('用药记录', style: TextStyle(fontSize: AppTheme.titleLarge)),
                  subtitle: const Text('查看历史用药情况', style: TextStyle(fontSize: AppTheme.bodyMedium)),
                  trailing: const Icon(Icons.chevron_right, size: 32),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecordScreen()),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // ── 今日用药列表 ──
              if (!_loading && _medicationCount > 0) ...[
                Text(
                  '📋 今日用药',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                // 药品概要卡片
                Center(
                  child: Text(
                    '共 $_medicationCount 种药品',
                    style: const TextStyle(
                      fontSize: AppTheme.bodyLarge,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
              ],

              // ── 预警信息 ──
              if (_alertCount > 0) ...[
                Text(
                  '⚠️ 预警信息',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                ..._alerts.take(3).map((alert) {
                  final name = alert['medication_name'] as String? ?? '';
                  final alertsList = alert['alerts'] as List<dynamic>? ?? [];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: Theme.of(context).textTheme.titleLarge),
                          ...alertsList.map((a) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  a['severity'] == 'danger' ? Icons.error : Icons.warning,
                                  size: 20,
                                  color: a['severity'] == 'danger'
                                      ? AppTheme.dangerColor
                                      : AppTheme.warningColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    a['message'] as String? ?? '',
                                    style: TextStyle(
                                      fontSize: AppTheme.bodyMedium,
                                      color: a['severity'] == 'danger'
                                          ? AppTheme.dangerColor
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  );
                }),
              ],

              // ── 查看全部按钮 ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MedicinesScreen()),
                    );
                  },
                  icon: const Icon(Icons.medication, size: 28),
                  label: const Text('查看全部药品'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
