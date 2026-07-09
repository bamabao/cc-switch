import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'clay_time_picker.dart';

/// 爸妈宝 — 服药时段选择组件（拖拽排序+默认预置+自定义时间）
class TimeSlotSelector extends StatefulWidget {
  final List<TimeOfDay> timeSlots;
  final ValueChanged<List<TimeOfDay>> onChanged;
  /// 当用户在时间选择器中点击【确认】后触发（用于联动弹出提醒方式选择弹窗）
  final ValueChanged<TimeOfDay>? onTimeConfirmed;

  const TimeSlotSelector({
    super.key,
    required this.timeSlots,
    required this.onChanged,
    this.onTimeConfirmed,
  });

  @override
  State<TimeSlotSelector> createState() => _TimeSlotSelectorState();
}

class _TimeSlotSelectorState extends State<TimeSlotSelector> {
  /// 默认快捷选项（仅用于初始化填充）
  static const List<String> _defaultLabels = ['早', '中', '晚', '12点'];
  static const List<TimeOfDay> _defaultTimes = [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 18, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
  ];

  late List<_TimeSlotItem> _items;

  @override
  void initState() {
    super.initState();
    _initItems();
  }

  @override
  void didUpdateWidget(TimeSlotSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeSlots != widget.timeSlots) {
      _initItems();
    }
  }

  void _initItems() {
    if (widget.timeSlots.isEmpty) {
      _items = List.generate(_defaultLabels.length, (i) => _TimeSlotItem(
        label: _defaultLabels[i],
        time: _defaultTimes[i],
      ));
    } else {
      _items = widget.timeSlots.map((t) => _TimeSlotItem(
        label: _formatTime(t),
        time: t,
      )).toList();
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _removeAt(int index) {
    setState(() => _items.removeAt(index));
    _notifyChanged();
  }

  void _addCustomTime() async {
    final picked = await ClayTimePicker.show(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _items.add(_TimeSlotItem(label: _formatTime(picked), time: picked));
      });
      _notifyChanged();
      widget.onTimeConfirmed?.call(picked);
    }
  }

  void _notifyChanged() {
    widget.onChanged(_items.map((e) => e.time).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('服用时间', style: TextStyle(fontSize: AppTheme.bodyLarge, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('暂无时段，请点击下方添加', style: TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
                _notifyChanged();
              },
              proxyDecorator: (child, index, animation) {
                return Transform.scale(
                  scale: 1.0 + 0.05 * animation.value,
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return Dismissible(
                  key: ValueKey('time_${item.time.hour}_${item.time.minute}_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppTheme.warningColor, size: 28),
                  ),
                  onDismissed: (_) => _removeAt(index),
                  child: _buildTimeChip(item, index),
                );
              },
            ),
          const SizedBox(height: 12),
          // 自定义时间按钮
          GestureDetector(
            onTap: _addCustomTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 30),
                  SizedBox(width: 8),
                  Text('自定义时间', style: TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(_TimeSlotItem item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: ValueKey('time_${item.time.hour}_${item.time.minute}_$index'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            // 拖拽手柄
            const Icon(Icons.drag_handle, color: AppTheme.textSecondary, size: 28),
            const SizedBox(width: 12),
            // 时段标签 — 点击弹出中文时间选择器修改时间
            GestureDetector(
              onTap: () => _editTime(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  item.label,
                  style: const TextStyle(fontSize: 26, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const Spacer(),
            // 删除按钮
            GestureDetector(
              onTap: () => _removeAt(index),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.warningColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 点击时间标签 → 弹出中文汉化黏土时间选择器修改时分
  Future<void> _editTime(int index) async {
    final item = _items[index];
    final picked = await ClayTimePicker.show(
      context: context,
      initialTime: item.time,
    );
    if (picked != null) {
      setState(() {
        _items[index] = _TimeSlotItem(label: _formatTime(picked), time: picked);
      });
      _notifyChanged();
      widget.onTimeConfirmed?.call(picked);
    }
  }
}

class _TimeSlotItem {
  final String label;
  final TimeOfDay time;
  _TimeSlotItem({required this.label, required this.time});
}


