import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../widgets/elder_calendar.dart';

/// 用药记录页 — 适老日历视图 + 大字明细列表
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final ApiService _api = ApiService();
  DateTime _selectedDate = DateTime.now();
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<dynamic> _allLogs = [];
  bool _loading = true;
  int _elderId = 1;
  int _total = 0;
  int _confirmed = 0;
  int _missed = 0;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      try {
        final user = await _api.getMe();
        _elderId = user.id;
      } catch (_) {}
      final result = await _api.get('${ApiConfig.medications}/logs/history',
          queryParams: {'elder_id': '$_elderId', 'days': '30'});
      if (!mounted) return;
      setState(() {
        _allLogs = result['items'] as List<dynamic>? ?? [];
        _total = result['total'] as int? ?? 0;
        _confirmed = result['confirmed'] as int? ?? 0;
        _missed = result['missed'] as int? ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// 日期状态：0=无记录 1=全部已服 2=部分服药 3=漏服
  int _calcDayStatus(int year, int month, int day) {
    final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final dayLogs = _allLogs.where((log) {
      final scheduled = log['scheduled_time'] as String? ?? '';
      return scheduled.startsWith(dateStr);
    }).toList();
    if (dayLogs.isEmpty) return 0;
    final allConfirmed = dayLogs.every((l) => l['status'] == 'confirmed');
    final anyConfirmed = dayLogs.any((l) => l['status'] == 'confirmed');
    if (allConfirmed) return 1;
    if (anyConfirmed) return 2;
    return 3;
  }

  List<dynamic> get _selectedDayLogs {
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    return _allLogs.where((log) {
      final scheduled = log['scheduled_time'] as String? ?? '';
      return scheduled.startsWith(dateStr);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('用药记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            onPressed: _loadLogs,
            tooltip: '刷新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        child: Column(
          children: [
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildCalendarCard(),
              const SizedBox(height: 4),
              _buildLegend(),
              const SizedBox(height: 4),
              Expanded(child: _buildDetailList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingMd, AppTheme.spacingMd, 0),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            // 月份切换栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 40,
                  color: AppTheme.primaryColor,
                  onPressed: () => setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1)),
                ),
                Text(
                  '${_viewMonth.year} 年 ${_viewMonth.month} 月',
                  style: const TextStyle(
                    fontSize: AppTheme.titleLarge,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 40,
                  color: AppTheme.primaryColor,
                  onPressed: () => setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ElderCalendar 组件
            ElderCalendar(
              year: _viewMonth.year,
              month: _viewMonth.month,
              selectedDate: _selectedDate,
              dayStatusFn: _calcDayStatus,
              onDateSelected: (date) => setState(() => _selectedDate = date),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendChip(AppTheme.secondaryColor, '已服完'),
          const SizedBox(width: 20),
          _legendChip(const Color(0xFFFDD835), '部分服'),
          const SizedBox(width: 20),
          _legendChip(AppTheme.warningColor, '漏服'),
          const SizedBox(width: 20),
          _legendChip(AppTheme.textSecondary.withValues(alpha: 0.25), '无记录'),
        ],
      ),
    );
  }

  Widget _legendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDetailList() {
    final logs = _selectedDayLogs;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedDate.month}月${_selectedDate.day}日',
                  style: const TextStyle(
                    fontSize: AppTheme.titleLarge,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '总$_total · 已服$_confirmed · 漏服$_missed',
                  style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXl),
              child: Center(
                child: Text(
                  '今日暂无用药记录',
                  style: TextStyle(fontSize: AppTheme.titleMedium, color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
                children: [
                  ...logs.map((log) => _buildLogItem(log)),
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    child: Center(
                      child: Text(
                        logs.every((l) => l['status'] == 'confirmed')
                            ? '✅ 今日全部按时服用了！'
                            : '⚠️ 有药品漏服，请注意',
                        style: TextStyle(
                          fontSize: AppTheme.titleMedium,
                          color: logs.every((l) => l['status'] == 'confirmed')
                              ? AppTheme.secondaryColor
                              : AppTheme.warningColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogItem(dynamic log) {
    final name = log['medication_name'] as String? ?? '未知药品';
    final status = log['status'] as String? ?? 'missed';
    final scheduledTime = log['scheduled_time'] as String? ?? '';
    final dosage = log['dosage_taken'] as double?;
    final isConfirmed = status == 'confirmed';
    final timeOnly = scheduledTime.length >= 16 ? scheduledTime.substring(11, 16) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isConfirmed
                  ? AppTheme.secondaryColor.withValues(alpha: 0.15)
                  : AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isConfirmed ? Icons.check_circle : Icons.cancel,
              color: isConfirmed ? AppTheme.secondaryColor : AppTheme.warningColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: AppTheme.titleMedium,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dosage != null ? '$timeOnly · ${dosage}剂量' : timeOnly,
                  style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isConfirmed
                  ? AppTheme.secondaryColor.withValues(alpha: 0.15)
                  : AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isConfirmed ? '已服' : '漏服',
              style: TextStyle(
                fontSize: AppTheme.bodyLarge,
                color: isConfirmed ? AppTheme.secondaryColor : AppTheme.warningColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
