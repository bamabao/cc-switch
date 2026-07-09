import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// 爸妈宝 — 黏土风格中文时间选择器（24小时制 v2）
///
/// 完全汉化，适配项目橙绿黏土 UI 规范，大字号适老化
/// v2 改进：
/// - 24小时制（00:00-23:59），去掉上午/下午切换
/// - 修复分钟滚轮空白占位符 bug（用 FixedExtentScrollController）
/// - 按钮色彩对齐规范：取消=暖橙边框+暖橙文字 / 确认=嫩绿边框+嫩绿文字
class ClayTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onConfirmed;

  const ClayTimePicker({
    super.key,
    required this.initialTime,
    required this.onConfirmed,
  });

  /// 以对话框形式弹出
  static Future<TimeOfDay?> show({
    required BuildContext context,
    TimeOfDay initialTime = const TimeOfDay(hour: 8, minute: 0),
  }) {
    return showDialog<TimeOfDay>(
      context: context,
      builder: (ctx) {
        return _ClayTimePickerDialog(
          initialTime: initialTime,
        );
      },
    );
  }

  @override
  State<ClayTimePicker> createState() => _ClayTimePickerState();
}

class _ClayTimePickerState extends State<ClayTimePicker> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// ═══════════════════════════════════════════════════════
//  对话框实现
// ═══════════════════════════════════════════════════════

class _ClayTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;

  const _ClayTimePickerDialog({required this.initialTime});

  @override
  State<_ClayTimePickerDialog> createState() => _ClayTimePickerDialogState();
}

class _ClayTimePickerDialogState extends State<_ClayTimePickerDialog> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour.clamp(0, 23);   // 0-23
    _selectedMinute = widget.initialTime.minute.clamp(0, 59); // 0-59
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── 标题 ───
            const Text(
              '选择服药时间',
              style: TextStyle(
                fontSize: AppTheme.headlineMedium,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // ─── 24小时制双滚轮 ───
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 小时滚轮 00-23
                _buildWheel(
                  controller: _hourController,
                  range: 24,
                  selectedValue: _selectedHour,
                  onChanged: (v) => setState(() => _selectedHour = v),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                // 分钟滚轮 00-59
                _buildWheel(
                  controller: _minuteController,
                  range: 60,
                  selectedValue: _selectedMinute,
                  onChanged: (v) => setState(() => _selectedMinute = v),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingXl),

            // ─── 底部按钮 ───
            Row(
              children: [
                // 取消 — 暖橙边框 + 橙色文字
                Expanded(
                  child: _buildActionButton(
                    label: '取消',
                    borderColor: AppTheme.primaryColor,
                    textColor: AppTheme.primaryColor,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 16),
                // 确认 — 嫩绿边框 + 绿色文字
                Expanded(
                  child: _buildActionButton(
                    label: '确认',
                    borderColor: AppTheme.secondaryColor,
                    textColor: AppTheme.secondaryColor,
                    onTap: () {
                      final time = TimeOfDay(hour: _selectedHour, minute: _selectedMinute);
                      Navigator.pop(context, time);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 单个滚轮选择列（FixedExtentScrollController 确保初始化定位精准，无空白字符 bug）
  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int range,
    required int selectedValue,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 88,
      height: 240,
      child: ListWheelScrollView(
        controller: controller,
        itemExtent: 52,
        squeeze: 1.1,
        diameterRatio: 1.8,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) => onChanged(index),
        children: List.generate(range, (i) {
          final isSelected = i == selectedValue;
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Text(
                i.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: isSelected ? 40 : 30,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 底部操作按钮 — 纯边框+文字风格
  Widget _buildActionButton({
    required String label,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: borderColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          border: Border.all(color: borderColor, width: 2.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.titleMedium,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
