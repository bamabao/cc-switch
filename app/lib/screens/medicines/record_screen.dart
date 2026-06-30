import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// 用药记录页 — 日历视图 + 明细列表
/// P0-4：超大日历格子 ≥80×80px，直观区分服药/漏服
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  DateTime _selectedDate = DateTime.now();
  int _currentMonth = DateTime.now().month;
  int _currentYear = DateTime.now().year;

  // 模拟数据
  final Map<String, bool> _medicationStatus = {
    '2026-06-30': true,
    '2026-06-29': true,
    '2026-06-28': false,
    '2026-06-27': true,
    '2026-06-26': false,
  };

  bool _hasTaken(String dateStr) => _medicationStatus[dateStr] ?? false;

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
      appBar: AppBar(title: const Text('用药记录')),
      body: Column(
        children: [
          _buildCalendar(),
          const SizedBox(height: 8),
          _buildLegend(),
          const SizedBox(height: 8),
          Expanded(child: _buildDetailList()),
        ],
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
            ...List.generate(
              (startWeekday + daysInMonth + 6) ~/ 7,
              (weekIndex) => Row(
                children: List.generate(7, (dayIndex) {
                  final dayNum = weekIndex * 7 + dayIndex - startWeekday + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 56));
                  }
                  final dateStr =
                      '$_currentYear-${_currentMonth.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
                  final isToday = dateStr ==
                      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
                  final isSelected = dayNum == _selectedDate.day &&
                      _currentMonth == _selectedDate.month;
                  final hasStatus =
                      _medicationStatus.containsKey(dateStr);
                  final taken = hasStatus && _medicationStatus[dateStr]!;

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
                              ? AppTheme.primaryColor
                                  .withValues(alpha: 0.15)
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
                            if (hasStatus)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: taken
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
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final taken = _hasTaken(dateStr);

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
            child: Text(
              '${_selectedDate.month}月${_selectedDate.day}日 用药记录',
              style: const TextStyle(
                fontSize: AppTheme.titleMedium,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          if (taken)
            _buildRecordItem('阿莫西林胶囊', '2粒', '早餐后', true)
          else
            _buildRecordItem('阿莫西林胶囊', '2粒', '早餐后', false),
          _buildRecordItem('维生素D片', '1粒', '早餐后', taken),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: taken ? AppTheme.secondaryColor : AppTheme.warningColor,
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
              taken ? '✅ 今日已按量服药' : '⚠️ 今日可能有药品漏服',
              style: TextStyle(
                fontSize: AppTheme.bodyLarge,
                color: taken ? AppTheme.secondaryColor : AppTheme.warningColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(
      String name, String dosage, String time, bool taken) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
      child: Row(
        children: [
          Icon(
            taken ? Icons.check_circle : Icons.cancel,
            color:
                taken ? AppTheme.secondaryColor : AppTheme.textSecondary.withValues(alpha: 0.5),
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
                Text('$dosage · $time',
                    style: const TextStyle(
                        fontSize: AppTheme.bodyMedium,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: taken
                  ? AppTheme.secondaryColor.withValues(alpha: 0.15)
                  : AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              taken ? '已服' : '漏服',
              style: TextStyle(
                fontSize: AppTheme.bodyMedium,
                color:
                    taken ? AppTheme.secondaryColor : AppTheme.warningColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
