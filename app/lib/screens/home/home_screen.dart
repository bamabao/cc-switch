import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../widgets/medicine_checkin_card.dart';
import '../medicines/medicines_screen.dart';
import '../medicines/add_medicine_screen.dart';
import '../medicines/record_screen.dart';
import '../medicines/medicine_detail_screen.dart';
import '../voice/voice_screen.dart';
import '../profile/settings_screen.dart';

/// 首页 / Dashboard — 对接后端真实API
/// v3.3 新增：竖向服药打卡卡片列表（黏土风格圆形按钮）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  String _greeting = '早上好！';
  int _medicationCount = 0;
  int _alertCount = 0;
  int _pendingCount = 0;   // 待服用药品数
  List<dynamic> _alerts = [];
  List<dynamic> _checkinItems = [];
  bool _loading = true;
  int _elderId = 1;

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
      // 尝试获取真实用户ID
      try {
        final user = await _api.getMe();
        _elderId = user.id;
      } catch (_) {}

      final medsResult = await _api.get(ApiConfig.medications, queryParams: {
        'elder_id': '$_elderId',
      });
      final medications = medsResult['items'] as List<dynamic>? ?? [];
      final approved = medications.where((m) => m['status'] == 'approved').toList();

      final alertsResult = await _api.get('${ApiConfig.medications}/alerts', queryParams: {
        'elder_id': '$_elderId',
      });
      final alerts = alertsResult['items'] as List<dynamic>? ?? [];

      // 加载今日打卡状态
      List<dynamic> checkinItems = [];
      int pending = 0;
      try {
        final checkinResult = await _api.getTodayCheckin(elderId: _elderId);
        checkinItems = checkinResult['items'] as List<dynamic>? ?? [];
        pending = checkinResult['total_pending'] as int? ?? 0;
      } catch (_) {
        checkinItems = [];
        pending = 0;
      }

      if (!mounted) return;
      setState(() {
        _medicationCount = approved.length;
        _alertCount = alerts.length;
        _alerts = alerts;
        _checkinItems = checkinItems;
        _pendingCount = pending;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// 打卡/撤销打卡
  Future<void> _handleCheckinTap(dynamic item, int scheduleIndex) async {
    final medicationId = item['medication_id'] as int;
    final schedules = item['schedules'] as List<dynamic>;
    if (scheduleIndex >= schedules.length) return;
    final schedule = schedules[scheduleIndex];
    final scheduleId = schedule['schedule_id'] as int;
    final currentlyChecked = schedule['checked'] as bool;

    try {
      if (currentlyChecked) {
        // 撤销打卡
        await _api.undoCheckin(
          medicationId: medicationId,
          elderId: _elderId,
          scheduleId: scheduleId,
        );
      } else {
        // 打卡
        await _api.checkinMedication(
          medicationId: medicationId,
          elderId: _elderId,
          scheduleIndex: scheduleIndex,
        );
      }
      // 刷新数据
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlyChecked ? '撤销失败：$e' : '打卡失败：$e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
              // ── 头部问候（原有保留） ──
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
                                ? '今天有 $_pendingCount 种药需要服用'
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

              // ── 语音快捷入口（原有保留） ──
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

              // ── 用药记录入口（原有保留） ──
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

              // ── 今日用药列表（标题+打卡卡片列表，新增竖向卡片） ──
              if (!_loading && _medicationCount > 0) ...[
                Row(
                  children: [
                    const Text(
                      '📋 今日用药',
                      style: TextStyle(
                        fontSize: AppTheme.headlineMedium,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '共 $_medicationCount 种药品',
                      style: const TextStyle(
                        fontSize: AppTheme.bodyLarge,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // 竖向打卡卡片列表（新增）
                ..._buildCheckinCards(),
                const SizedBox(height: AppTheme.spacingMd),
              ],

              // ── 预警信息（原有保留） ──
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

              // ── 查看全部按钮（原有保留） ──
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

              // ── + 添加药品按钮（原有保留） ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final added = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
                    );
                    if (added == true) _loadData();
                  },
                  icon: const Icon(Icons.add, size: 28),
                  label: const Text('添加药品'),
                ),
              ),

              // 底部留空（导航栏间距）
              const SizedBox(height: AppTheme.spacingMd),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建黏土风格服药打卡卡片列表
  List<Widget> _buildCheckinCards() {
    return _checkinItems.map((item) {
      final medicationId = item['medication_id'] as int;
      final name = item['name'] as String? ?? '';
      final dosagePerTake = item['dosage_per_take'];
      final unit = item['unit'] as String? ?? '';
      final schedules = item['schedules'] as List<dynamic>? ?? [];
      final totalSlots = item['total_slots'] as int? ?? 0;
      final checkedSlots = item['checked_slots'] as int? ?? 0;

      // 只展示第一个时段？全部展示？王总要求每个药品展示一张卡片
      // 取第一个时段信息展示，灰色小字显示当前打卡状态
      String dosageInfo = '';
      if (schedules.isNotEmpty) {
        final firstSchedule = schedules[0];
        final time = firstSchedule['time'] as String? ?? '';
        if (dosagePerTake != null && unit.isNotEmpty) {
          dosageInfo = '$dosagePerTake $unit · $time';
        } else {
          dosageInfo = time;
        }
        if (totalSlots > 1) {
          dosageInfo += ' （已打卡 $checkedSlots/$totalSlots 次）';
        }
      }

      // 取该药品当前所有时段是否全部已打卡 → 决定按钮颜色
      final allChecked = checkedSlots >= totalSlots;

      // 若已全部打卡，isChecked=true（绿色），否则 false（红色）
      // 但我们按王总设计：红色=待服药，绿色=已打卡
      // 卡片只展示第一个时段，点击打卡打到第一个未打卡时段
      // 反向：全部已打卡则绿色，否则红色

      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        child: MedicineCheckinCard(
          medicationId: medicationId,
          medicationName: name,
          dosageInfo: dosageInfo,
          isChecked: allChecked,
          onCheckinTap: () {
            // 找到第一个未打卡的时段索引
            final firstUncheckedIndex = schedules.indexOf(
              schedules.firstWhere(
                (s) => s['checked'] != true,
                orElse: () => schedules[0],
              ),
            );
            _handleCheckinTap(item, firstUncheckedIndex);
          },
          onDetailTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MedicineDetailScreen(
                  medicationId: medicationId,
                  medicationName: name,
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }
}
