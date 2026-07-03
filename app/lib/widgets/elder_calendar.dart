import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 适老日历组件 — 大号格子(80×80px)+颜色状态填充
///
/// 用法：
/// ```dart
/// ElderCalendar(
///   year: 2026,
///   month: 7,
///   selectedDate: selectedDate,
///   dayStatusFn: (y, m, d) => 0..3,
///   onDateSelected: (date) => setState(() => selectedDate = date),
/// );
/// ```
///
/// dayStatusFn 返回值：
///   0 = 无记录(灰色)
///   1 = 全部已服(绿色)
///   2 = 部分服药(黄色)
///   3 = 漏服(红色)
class ElderCalendar extends StatelessWidget {
  final int year;
  final int month;
  final DateTime selectedDate;
  final int Function(int year, int month, int day) dayStatusFn;
  final ValueChanged<DateTime> onDateSelected;

  const ElderCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.selectedDate,
    required this.dayStatusFn,
    required this.onDateSelected,
  });

  static const List<String> _weekHeaders = ['日', '一', '二', '三', '四', '五', '六'];

  /// 将状态码(0~3)转为背景颜色
  static Color _statusToColor(int status) {
    switch (status) {
      case 1:
        return AppTheme.secondaryColor; // 绿 → 已服完
      case 2:
        return const Color(0xFFFDD835); // 黄 → 部分服药
      case 3:
        return AppTheme.warningColor; // 红 → 漏服
      default:
        return Colors.transparent; // 灰/无记录 → 透明
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=周日

    final today = DateTime.now();

    return Column(
      children: [
        // 星期头
        Row(
          children: _weekHeaders
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: AppTheme.bodyLarge,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        // 日期格：每行固定80px高
        ...List.generate(
          (startWeekday + daysInMonth + 6) ~/ 7,
          (weekIndex) => SizedBox(
            height: 80,
            child: Row(
              children: List.generate(7, (dayIndex) {
                final dayNum = weekIndex * 7 + dayIndex - startWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox());
                }

                final isToday = dayNum == today.day &&
                    month == today.month &&
                    year == today.year;
                final isSelected = dayNum == selectedDate.day &&
                    month == selectedDate.month &&
                    year == selectedDate.year;

                final status = dayStatusFn(year, month, dayNum);
                final bgColor = _statusToColor(status);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDateSelected(DateTime(year, month, dayNum)),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? bgColor != Colors.transparent
                                ? bgColor.withValues(alpha: 0.65)
                                : AppTheme.primaryColor.withValues(alpha: 0.15)
                            : bgColor != Colors.transparent
                                ? bgColor.withValues(alpha: 0.20)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: AppTheme.primaryColor, width: 2.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: isToday ? AppTheme.titleLarge : AppTheme.bodyLarge,
                            color: isToday
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                            fontWeight:
                                isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
