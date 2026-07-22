import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import 'clay_time_picker.dart';

/// 爸妈宝 — 服药时段选择组件（每时段独立服药数量+单位+时间）
///
/// v3.8 新增：
/// - 每时段独立数量输入框 + 单位选择器
/// - 每条时间独立圆角悬浮卡片 + 柔和阴影
/// - 自定义时间带出数量 / 单位输入项
class TimeSlotSelector extends StatefulWidget {
  final List<TimeSlotData> timeSlots;
  final ValueChanged<List<TimeSlotData>> onChanged;

  const TimeSlotSelector({
    super.key,
    required this.timeSlots,
    required this.onChanged,
  });

  @override
  State<TimeSlotSelector> createState() => _TimeSlotSelectorState();
}

class _TimeSlotSelectorState extends State<TimeSlotSelector> {
  late List<_TimeSlotItem> _items;
  late String _unit;
  bool _initialized = false;

  static const List<String> _unitOptions = ['粒', '片', '克 (g)', '毫升 (ml)', '瓶', '袋', '支', '丸', '毫克 (mg)'];

  @override
  void initState() {
    super.initState();
    _initItems();
  }

  @override
  void didUpdateWidget(TimeSlotSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized && widget.timeSlots.isNotEmpty) {
      _initItems();
    }
  }

  void _initItems() {
    if (widget.timeSlots.isEmpty) {
      _unit = '粒';
      _items = [
        _TimeSlotItem(time: const TimeOfDay(hour: 8, minute: 0), dosage: '1', unit: '粒'),
        _TimeSlotItem(time: const TimeOfDay(hour: 12, minute: 0), dosage: '1', unit: '粒'),
        _TimeSlotItem(time: const TimeOfDay(hour: 18, minute: 0), dosage: '1', unit: '粒'),
      ];
    } else {
      _unit = widget.timeSlots.first.unit;
      _items = widget.timeSlots.map((d) => _TimeSlotItem(
        time: d.time,
        dosage: d.dosage,
        unit: d.unit,
      )).toList();
    }
    _initialized = true;
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
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
        _items.add(_TimeSlotItem(time: picked, dosage: '1', unit: _unit));
      });
      _notifyChanged();
    }
  }

  void _editTime(int index) async {
    final item = _items[index];
    final picked = await ClayTimePicker.show(
      context: context,
      initialTime: item.time,
    );
    if (picked != null) {
      setState(() => _items[index] = item.copyWith(time: picked));
      _notifyChanged();
    }
  }

  void _onUnitChanged(String val) {
    setState(() {
      _unit = val;
      _items = _items.map((e) => e.copyWith(unit: val)).toList();
    });
    _notifyChanged();
  }

  void _addCustomUnit() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('新增单位', style: TextStyle(fontSize: AppTheme.titleLarge, color: AppTheme.textPrimary)),
        content: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: '输入单位名称',
              hintStyle: TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              minimumSize: const Size(120, AppTheme.buttonHeight - 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                _onUnitChanged(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textOnDark)),
          ),
        ],
      ),
    );
  }

  void _notifyChanged() {
    widget.onChanged(_items.map((e) => TimeSlotData(
      time: e.time,
      dosage: e.dosage,
      unit: e.unit,
    )).toList());
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
          Row(
            children: [
              const Icon(Icons.access_time, color: AppTheme.primaryColor, size: 30),
              const SizedBox(width: 10),
              const Text(
                '服用时间',
                style: TextStyle(fontSize: AppTheme.bodyLarge, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              // 统一单位选择器
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _unitOptions.contains(_unit) ? _unit : _unitOptions.first,
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor, size: 26),
                    style: const TextStyle(fontSize: 20, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                    items: [
                      ..._unitOptions.map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u, style: const TextStyle(fontSize: 18, color: AppTheme.textPrimary)),
                      )),
                      const DropdownMenuItem(
                        enabled: false,
                        child: Divider(height: 1, color: AppTheme.textSecondary),
                      ),
                      DropdownMenuItem(
                        value: '__custom__',
                        enabled: false,
                        child: GestureDetector(
                          onTap: _addCustomUnit,
                          child: const Row(
                            children: [
                              Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 22),
                              SizedBox(width: 4),
                              Text('自定义', style: TextStyle(fontSize: 18, color: AppTheme.primaryColor)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == '__custom__') {
                        _addCustomUnit();
                      } else if (val != null) {
                        _onUnitChanged(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Text(
              '每时段可独立设置服药数量',
              style: TextStyle(fontSize: AppTheme.bodySmall, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text(
                '暂无时段，请点击下方添加',
                style: TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary),
              ),
            )
          else
            ...List.generate(_items.length, (i) => _buildTimeEntry(i)),
          const SizedBox(height: 16),
          // 自定义时间按钮 — 橙色渐变悬浮
          GestureDetector(
            onTap: _addCustomTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text(
                    '自定义时间',
                    style: TextStyle(
                      fontSize: AppTheme.bodyLarge,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单条服用时间 — 悬浮小卡片：数量 + 单位 + 时间 + 删除
  Widget _buildTimeEntry(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 拖拽手柄
            const Icon(Icons.drag_handle, color: AppTheme.textLightGray, size: 24),
            const SizedBox(width: 6),
            // 数量输入框（软凹槽内嵌）
            Container(
              width: 72,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                boxShadow: [
                  // 内嵌凹槽效果
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_DecimalInputFormatter()],
                controller: TextEditingController.fromValue(
                  TextEditingValue(text: item.dosage, selection: TextSelection.collapsed(offset: item.dosage.length)),
                ),
                style: const TextStyle(fontSize: 26, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                ),
                onChanged: (val) => _items[index] = item.copyWith(dosage: val),
                onEditingComplete: () => _notifyChanged(),
              ),
            ),
            const SizedBox(width: 6),
            // 时间标签 — 点击可编辑
            GestureDetector(
              onTap: () => _editTime(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _formatTime(item.time),
                  style: const TextStyle(
                    fontSize: 24,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Spacer(),
            // 删除按钮 — 悬浮凸起
            GestureDetector(
              onTap: () => _removeAt(index),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warningColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 每时段数据（数量 + 单位 + 时间）
class TimeSlotData {
  final TimeOfDay time;
  final String dosage;
  final String unit;

  const TimeSlotData({
    required this.time,
    this.dosage = '1',
    this.unit = '粒',
  });
}

/// 内部数据模型
class _TimeSlotItem {
  final TimeOfDay time;
  final String dosage;
  final String unit;

  _TimeSlotItem({
    required this.time,
    this.dosage = '1',
    this.unit = '粒',
  });

  _TimeSlotItem copyWith({TimeOfDay? time, String? dosage, String? unit}) {
    return _TimeSlotItem(
      time: time ?? this.time,
      dosage: dosage ?? this.dosage,
      unit: unit ?? this.unit,
    );
  }
}

/// 数字输入格式化器 — 仅允许数字和小数点，禁止多个小数点
class _DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    final dotCount = '.'.allMatches(filtered).length;
    if (dotCount > 1) {
      final firstDot = filtered.indexOf('.');
      final sanitized = filtered.substring(0, firstDot + 1) +
          filtered.substring(firstDot + 1).replaceAll('.', '');
      return TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }
    if (filtered != newValue.text) {
      return TextEditingValue(
        text: filtered,
        selection: TextSelection.collapsed(offset: filtered.length),
      );
    }
    return newValue;
  }
}
