import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

/// 用药记录页 — 日历视图 + 明细列表
/// 对接后端真实用药日志API
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final ApiService _api = ApiService();
  DateTime _selectedDate = DateTime.now();
  int _currentMonth = DateTime.now().month;
  int _currentYear = DateTime.now().year;

  // 从后端拉的实际数据
  List<dynamic> _allLogs = [];
  bool _loading = true;
  int _elderId = 1;

  // 用药统计
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
      // 尝试获取真实用户ID
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

  /// 某一天的状态：true=全部已服 false=有漏服 null=无数据
  bool? _dayStatus(int year, int month, int day) {
    final dateStr =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final dayLogs = _allLogs.where((log) {
      final scheduled = log['scheduled_time'] as String? ?? '';
      return scheduled.startsWith(dateStr);
    }).toList();
    if (dayLogs.isEmpty) return null;
    // 只要有一条 confirmed 就算至少有服药记录
    return dayLogs.any((log) => log['status'] == 'confirmed');
  }

  /// 选中日期对应的明细
  List<dynamic> get _selectedDayLogs {
    final dateStr =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    return _allLogs.where((log) {
      final scheduled = log['scheduled_time'] as String? ?? '';
      return scheduled.startsWith(dateStr);
    }).toList();
  }

  void _prevMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
    });
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
            _buildCalendar(),
            const SizedBox(height: 8),
            _buildLegend(),
            const SizedBox(height: 8),
            Expanded(child: _buildDetailList()),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_currentYear, _currentMonth, 1);
    final lastDay = DateTime(_currentYear, _currentMonth + 1, 0);
    final startWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            // 月份切换
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 36,
                  color: AppTheme.primaryColor,
                  onPressed: _prevMonth,
                ),
                Text(
                  '$_currentYear 年 $_currentMonth 月',
                  style: const TextStyle(
                    fontSize: AppTheme.titleMedium,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 36,
                  color: AppTheme.primaryColor,
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 星期头
            Row(
              children: ['日', '一', '二', '三', '四', '五', '六']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                fontSize: AppTheme.bodyLarge,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // 日期格子
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...List.generate(
                (startWeekday + daysInMonth + 6) ~/ 7,
                (weekIndex) => Row(
                  children: List.generate(7, (dayIndex) {
                    final dayNum =
                        weekIndex * 7 + dayIndex - startWeekday + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 56));
                    }
                    final isToday = dayNum == DateTime.now().day &&
                        _currentMonth == DateTime.now().month &&
                        _currentYear == DateTime.now().year;
                    final isSelected = dayNum == _selectedDate.day &&
                        _currentMonth == _selectedDate.month &&
                        _currentYear == _selectedDate.year;
                    final status = _dayStatus(_currentYear, _currentMonth, dayNum);

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = DateTime(
                                _currentYear, _currentMonth, dayNum);
                          });
                        },
                        child: Container(
                          height: 56,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: AppTheme.bodyLarge,
                                  color: AppTheme.textPrimary,
                                  fontWeight:
                                      isToday ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (status != null)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    color: status
                                        ? AppTheme.secondaryColor
                                        : AppTheme.warningColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
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
          _legendDot(AppTheme.secondaryColor, '已服药'),
          const SizedBox(width: 24),
          _legendDot(AppTheme.warningColor, '漏服药'),
          const SizedBox(width: 24),
          _legendDot(AppTheme.textSecondary.withValues(alpha: 0.3), '无记录'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: AppTheme.bodyMedium,
                color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildDetailList() {
    final logs = _selectedDayLogs;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
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
                  '${_selectedDate.month}月${_selectedDate.day}日 用药记录',
                  style: const TextStyle(
                    fontSize: AppTheme.titleMedium,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '总$_total · 已服$_confirmed · 漏服$_missed',
                  style: const TextStyle(
                    fontSize: AppTheme.bodyMedium,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppTheme.spacingLg),
              child: Center(
                child: Text(
                  '今日暂无用药记录',
                  style: TextStyle(
                    fontSize: AppTheme.bodyLarge,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...logs.map((log) => _buildLogItem(log)),
          if (logs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: logs.every((l) => l['status'] == 'confirmed')
                        ? AppTheme.secondaryColor
                        : AppTheme.warningColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  left: AppTheme.spacingMd,
                  right: AppTheme.spacingMd,
                  bottom: AppTheme.spacingMd),
              child: Text(
                logs.every((l) => l['status'] == 'confirmed')
                    ? '✅ 今日已按量服药'
                    : '⚠️ 有药品漏服',
                style: TextStyle(
                  fontSize: AppTheme.bodyLarge,
                  color: logs.every((l) => l['status'] == 'confirmed')
                      ? AppTheme.secondaryColor
                      : AppTheme.warningColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
    final timeOnly = scheduledTime.length >= 16
        ? scheduledTime.substring(11, 16)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
      child: Row(
        children: [
          Icon(
            isConfirmed ? Icons.check_circle : Icons.cancel,
            color: isConfirmed
                ? AppTheme.secondaryColor
                : AppTheme.textSecondary.withValues(alpha: 0.5),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: AppTheme.bodyLarge,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500)),
                Text(dosage != null ? '$timeOnly · ${dosage}剂量' : timeOnly,
                    style: const TextStyle(
                        fontSize: AppTheme.bodyMedium,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isConfirmed
                  ? AppTheme.secondaryColor.withValues(alpha: 0.15)
                  : AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isConfirmed ? '已服' : '漏服',
              style: TextStyle(
                fontSize: AppTheme.bodyMedium,
                color: isConfirmed
                    ? AppTheme.secondaryColor
                    : AppTheme.warningColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
