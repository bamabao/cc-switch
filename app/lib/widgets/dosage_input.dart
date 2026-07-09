import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';

/// 爸妈宝 — 药品剂量输入组件（单次用量+单位下拉+每日频次）
class DosageInput extends StatefulWidget {
  final String dosageAmount;
  final String dosageUnit;
  final int frequencyPerDay;
  final int timeSlotCount;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<int> onFrequencyChanged;

  const DosageInput({
    super.key,
    this.dosageAmount = '',
    this.dosageUnit = '粒',
    this.frequencyPerDay = 1,
    this.timeSlotCount = 0,
    required this.onAmountChanged,
    required this.onUnitChanged,
    required this.onFrequencyChanged,
  });

  @override
  State<DosageInput> createState() => _DosageInputState();
}

class _DosageInputState extends State<DosageInput> {
  late TextEditingController _amountController;

  static const List<String> _defaultUnits = [
    '粒', '片', '克 (g)', '毫升 (ml)', '瓶', '袋', '支', '丸', '毫克 (mg)',
  ];

  late List<String> _units;
  late String _selectedUnit;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.dosageAmount);
    _units = List.from(_defaultUnits);
    _selectedUnit = widget.dosageUnit;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DosageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dosageAmount != oldWidget.dosageAmount &&
        widget.dosageAmount != _amountController.text) {
      _amountController.text = widget.dosageAmount;
    }
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
                setState(() {
                  _units.insert(0, text);
                  _selectedUnit = text;
                });
                widget.onUnitChanged(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textOnDark)),
          ),
        ],
      ),
    );
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
          // ─── 第一行：单次用量 + 单位 ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('单次用量', style: TextStyle(fontSize: AppTheme.bodyLarge, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.bgColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      _DecimalInputFormatter(),
                    ],
                    style: const TextStyle(fontSize: 30, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: '例如：0.5',
                      hintStyle: TextStyle(fontSize: 26, color: AppTheme.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    ),
                    onChanged: (val) => widget.onAmountChanged(val),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 单位下拉
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _units.contains(_selectedUnit) ? _selectedUnit : _units.first,
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textPrimary, size: 36),
                    style: const TextStyle(fontSize: 26, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                    items: [
                      ..._units.map((unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit, style: const TextStyle(fontSize: 24)),
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
                              Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 28),
                              SizedBox(width: 8),
                              Text('自定义单位', style: TextStyle(fontSize: 22, color: AppTheme.primaryColor)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == '__custom__') {
                        _addCustomUnit();
                      } else if (val != null) {
                        setState(() => _selectedUnit = val);
                        widget.onUnitChanged(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // ─── 第二行：每日频次 ───
          Row(
            children: [
              const Text('每日频次', style: TextStyle(fontSize: AppTheme.bodyLarge, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              const SizedBox(width: 16),
              Container(
                width: 120,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 30, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: widget.frequencyPerDay.toString(),
                    hintStyle: const TextStyle(fontSize: 26, color: AppTheme.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                  onChanged: (val) {
                    final freq = int.tryParse(val) ?? 1;
                    widget.onFrequencyChanged(freq.clamp(1, 99));
                  },
                ),
              ),
              const Spacer(),
              Text(
                '已设 ${widget.timeSlotCount} 个时段',
                style: const TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
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
    // 只允许数字和小数点
    final filtered = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');

    // 防止多个小数点
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
