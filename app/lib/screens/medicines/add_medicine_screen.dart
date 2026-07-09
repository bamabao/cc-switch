import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/reminder_service.dart';
import '../../widgets/dosage_input.dart';
import '../../widgets/time_slot_selector.dart';
import '../../widgets/reminder_dialog.dart';
import '../../models/medication_dose.dart';
import '../voice/voice_screen.dart';
import 'medicine_camera_screen.dart';

/// 药品录入页 — 三通道录入 + 剂量模块 + 服药提醒
/// 支持：药盒拍照 / 语音录入 / 手动手写录入
/// v2.2 新增：单次用量+单位下拉、多时段拖拽、提醒选择弹窗
class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  // ─── 控制器 ───
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  // ─── 服务 ───
  final ApiService _api = ApiService();
  final ReminderService _reminderService = ReminderService();

  // ─── 状态 ───
  String _selectedCategory = '内服';
  bool _showForm = true;
  bool _submitting = false;
  bool _ocrRunning = false;
  int _elderId = 1;

  // ─── 剂量数据（由子组件回传） ───
  String _dosageAmount = '';
  String _dosageUnit = '粒';
  int _frequencyPerDay = 1;
  List<TimeOfDay> _timeSlots = [
    const TimeOfDay(hour: 8, minute: 0),
    const TimeOfDay(hour: 12, minute: 0),
    const TimeOfDay(hour: 18, minute: 0),
    const TimeOfDay(hour: 0, minute: 0), // 12点
  ];
  // 用户已通过时段联动确认的提醒配置
  MedicationDose? _confirmedDose;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final user = await _api.getMe();
      if (mounted) setState(() {
        _elderId = user.id;
      });
    } catch (_) {}
  }

  static const List<String> _categories = ['内服', '外用', '针剂', '滋补'];
  static const Map<String, String> _categoryApiMap = {
    '内服': 'oral',
    '外用': 'external',
    '针剂': 'injection',
    '滋补': 'supplement',
  };
  List<IconData> get _categoryIcons => const [
    Icons.medication_liquid,
    Icons.medication,
    Icons.health_and_safety,
    Icons.spa,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// 校验单次用量 — 数字为空时弹窗提示
  bool _validateDosageAmount() {
    if (_dosageAmount.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请填写单次服用数量'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  /// 单位标准化映射 — OCR识别结果 → 下拉选项文本
  static const Map<String, String> _unitNormalizeMap = {
    'g': '克 (g)',
    '克': '克 (g)',
    'mg': '毫克 (mg)',
    '毫克': '毫克 (mg)',
    'ml': '毫升 (ml)',
    'mL': '毫升 (ml)',
    '毫升': '毫升 (ml)',
  };

  /// 将OCR识别的剂量字符串（如 "0.5g" "2粒" "15ml"）拆分为数字+单位
  void _parseOcrDosage(String dosageStr) {
    if (dosageStr.isEmpty) return;
    final match = RegExp(r'^(\d+\.?\d*)\s*(.+)$').firstMatch(dosageStr.trim());
    if (match != null) {
      final number = match.group(1)!;
      var unit = match.group(2)!.trim();
      // 标准化单位以匹配下拉选项
      unit = _unitNormalizeMap[unit] ?? unit;
      setState(() {
        _dosageAmount = number;
        _dosageUnit = unit;
      });
    } else {
      // 纯数字（无单位），只写用量
      setState(() => _dosageAmount = dosageStr.trim());
    }
  }

  // ─── 提交流程：提交药品 → 弹提醒选择 → 保存提醒 → 返回 ───
  void _submit() async {
    if (_submitting || _nameController.text.trim().isEmpty) return;
    // 必填校验：单次用量
    if (!_validateDosageAmount()) return;
    setState(() => _submitting = true);

    try {
      // Step 1: 提交药品到后端（直接通过，无需审核）
      final response = await _api.post(
        '${ApiConfig.medications}?elder_id=$_elderId',
        body: {
          'name': _nameController.text.trim(),
          'category': _categoryApiMap[_selectedCategory] ?? 'oral',
          'oral_form': 'tablet',
          // 映射到后端 dosages_per_take + unit 字段
          'dosage_per_take': double.tryParse(_dosageAmount) ?? 0.0,
          'unit': _dosageUnit.replaceAll(RegExp(r'\s*\(.+\)'), ''),
          'frequency_per_day': _frequencyPerDay,
          'time_slots': _timeSlots
              .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
              .toList(),
          'notes': _noteController.text.trim(),
          'status': 'approved',
        },
      );

      if (!mounted) return;

      final medicationId = response['id'] as int? ?? 0;

      // Step 2: 提醒方式（如果已在时段联动中确认过则直接用，否则弹出选择弹窗）
      final MedicationDose? dose = _confirmedDose ?? await showDialog<MedicationDose>(
        context: context,
        barrierDismissible: false, // 不可跳过
        builder: (ctx) => ReminderDialog(
          medicationName: _nameController.text.trim(),
          onConfirm: (d) => Navigator.pop(ctx, d),
        ),
      );

      if (!mounted || dose == null) return;

      // Step 3: 保存提醒到后端
      final doseWithSlots = dose.copyWith(
        dosageAmount: _dosageAmount,
        dosageUnit: _dosageUnit,
        frequencyPerDay: _timeSlots.length,
        timeSlots: _timeSlots,
      );
      await _reminderService.scheduleAllSlots(
        medicationId: medicationId,
        medicationName: _nameController.text.trim(),
        dose: doseWithSlots,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('药品已添加，提醒已设置！'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加失败：$e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// OCR无文字 → 引导用户调整拍照
  void _showOcrGuideDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('拍照识别不到文字', style: TextStyle(fontSize: 28)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('试试以下方法：', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            SizedBox(height: 12),
            _GuideStep(icon: Icons.touch_app, text: '点击屏幕对焦药盒/说明书'),
            SizedBox(height: 8),
            _GuideStep(icon: Icons.wb_sunny, text: '确保光线充足，避免反光和阴影'),
            SizedBox(height: 8),
            _GuideStep(icon: Icons.straighten, text: '让药盒/说明书占满取景框'),
            SizedBox(height: 8),
            _GuideStep(icon: Icons.hdr_on, text: '如表面覆膜反光，稍微倾斜角度'),
            SizedBox(height: 16),
            Text('重拍或手动填写都可以', style: TextStyle(fontSize: 22, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('知道了', style: TextStyle(fontSize: 24)),
          ),
        ],
      ),
    );
  }

  /// 时段选择确认后 → 自动弹出提醒方式选择弹窗
  void _onTimeSlotConfirmed() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return; // 只有已填药品名才弹

    final dose = await showDialog<MedicationDose>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReminderDialog(
        medicationName: name,
        onConfirm: (dose) => Navigator.pop(ctx, dose),
      ),
    );

    if (!mounted || dose == null) return;

    // 保存到状态变量，提交时使用
    setState(() {
      _confirmedDose = dose.copyWith(
        dosageAmount: _dosageAmount,
        dosageUnit: _dosageUnit,
        frequencyPerDay: _timeSlots.length,
        timeSlots: _timeSlots,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('提醒方式已设置，提交药品时一并保存'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 适老一键朗读 — 朗读页面核心文字
  void _readPageAloud() {
    final text = '药品名称：${_nameController.text}，'
        '用量：$_dosageAmount$_dosageUnit，'
        '每日$_frequencyPerDay次，'
        '服药时段：${_timeSlots.length}个时段，'
        '注意事项：${_noteController.text}';
    ReminderService.readPageText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('添加药品'),
        actions: [
          // 一键朗读按钮
          IconButton(
            icon: const Icon(Icons.volume_up, size: 28),
            onPressed: _readPageAloud,
            tooltip: '朗读页面文字',
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已通知子女帮忙添加药品'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              '子女帮我录入',
              style: TextStyle(
                fontSize: AppTheme.bodyMedium,
                color: AppTheme.textOnDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 三通道入口
            _buildInputChannels(),
            const SizedBox(height: AppTheme.spacingLg),

            // 分类选择
            _buildCategorySelector(),
            const SizedBox(height: AppTheme.spacingLg),

            // 表单
            if (_showForm) _buildForm(),
            const SizedBox(height: AppTheme.spacingLg),

            // 剂量模块
            if (_showForm) ...[
              DosageInput(
                dosageAmount: _dosageAmount,
                dosageUnit: _dosageUnit,
                frequencyPerDay: _frequencyPerDay,
                timeSlotCount: _timeSlots.length,
                onAmountChanged: (val) => setState(() => _dosageAmount = val),
                onUnitChanged: (val) => setState(() => _dosageUnit = val),
                onFrequencyChanged: (val) => setState(() => _frequencyPerDay = val),
              ),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            // 服药时段选择
            if (_showForm) ...[
              TimeSlotSelector(
                timeSlots: _timeSlots,
                onChanged: (slots) => setState(() => _timeSlots = slots),
                onTimeConfirmed: (time) => _onTimeSlotConfirmed(),
              ),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            // 提交按钮
            if (_showForm) _buildSubmitButton(),
            if (_submitting)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_ocrRunning)
              Container(
                padding: const EdgeInsets.all(32),
                child: const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在识别药盒…', style: TextStyle(fontSize: 20, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  原有组件保留（三通道、分类选择、输入字段、提交按钮）
  // ═══════════════════════════════════════════════════════

  Widget _buildInputChannels() {
    return Row(
      children: [
        Expanded(
          child: _buildChannelCard(
            icon: Icons.camera_alt,
            label: '拍照',
            subtitle: '拍药盒自动识别',
            color: AppTheme.primaryColor,
            onTap: () async {
              if (_ocrRunning) return;
              final cameraStatus = await Permission.camera.request();
              if (cameraStatus != PermissionStatus.granted) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('需要相机权限才能拍照识别'),
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
              if (!context.mounted) return;

              // 使用增强相机页（点击对焦+曝光控制+前置预处理）
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MedicineCameraScreen(
                    onImageCaptured: (File imageFile) async {
                      setState(() => _ocrRunning = true);

                      try {
                        final result = await _api.ocrRecognize(imageFile.path);
                        if (!context.mounted) return;

                        final name = result['name'] as String? ?? '';
                        final dosage = result['dosage'] as String? ?? '';
                        final frequency = result['frequency'] as String? ?? '';
                        final rawTexts = result['raw_texts'] as List<dynamic>? ?? [];
                        final success = result['success'] == true;

                        // ── 自动填入 ──
                        if (name.isNotEmpty) _nameController.text = name;
                        // OCR剂量解析："0.5g" → 数字0.5填入输入框，单位g匹配下拉
                        if (dosage.isNotEmpty) _parseOcrDosage(dosage);
                        if (frequency.isNotEmpty) {
                          final freqMatch = RegExp(r'(\d+)').firstMatch(frequency);
                          if (freqMatch != null) {
                            final freq = int.tryParse(freqMatch.group(1)!) ?? 1;
                            setState(() => _frequencyPerDay = freq.clamp(1, 6));
                          }
                        }

                        // ── 原始文本填入备注 ──
                        if (rawTexts.isNotEmpty && _noteController.text.isEmpty) {
                          _noteController.text = (rawTexts as List).join(' ');
                        }

                        if (success && name.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已自动填入：$name${dosage.isNotEmpty ? "，用量：$dosage" : ""}${frequency.isNotEmpty ? "，$frequency" : ""}'),
                              duration: const Duration(seconds: 3),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else if (rawTexts.isNotEmpty) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('识别到一些文字，已填入备注栏，请手动修正药品信息'),
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          if (!context.mounted) return;
                          _showOcrGuideDialog(context);
                        }
                        setState(() {});
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('OCR识别出错：$e'),
                            duration: const Duration(seconds: 3),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _ocrRunning = false);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildChannelCard(
            icon: Icons.mic,
            label: '语音录入',
            subtitle: '说话填写药品信息',
            color: AppTheme.secondaryColor,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceScreen()));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildChannelCard(
            icon: Icons.edit,
            label: '手动填写',
            subtitle: '自己输入药品信息',
            color: const Color(0xFF1565C0),
            onTap: () {
              _nameFocus.requestFocus();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChannelCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.shadowCard,
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 42),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 30,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 24,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '药品分类',
              style: TextStyle(
                fontSize: AppTheme.bodyLarge,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                _categories.length,
                (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = _categories[i]);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedCategory == _categories[i]
                              ? AppTheme.primaryColor.withValues(alpha: 0.12)
                              : AppTheme.bgColor,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusButton),
                          border: Border.all(
                            color: _selectedCategory == _categories[i]
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _categoryIcons[i],
                              color: _selectedCategory == _categories[i]
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _categories[i],
                              style: TextStyle(
                                fontSize: AppTheme.bodyMedium,
                                color: _selectedCategory == _categories[i]
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField(
              controller: _nameController,
              focusNode: _nameFocus,
              label: '药品名称',
              hint: '例如：阿莫西林胶囊',
              icon: Icons.medication,
              large: true,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _buildInputField(
              controller: _noteController,
              label: '注意事项',
              hint: '例如：忌酒',
              icon: Icons.info_outline,
              large: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required String hint,
    required IconData icon,
    bool large = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 28 : AppTheme.bodyLarge,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: large ? 12 : 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: TextStyle(
              fontSize: large ? 28 : AppTheme.titleMedium,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: large ? 26 : AppTheme.titleMedium,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: AppTheme.buttonHeight,
      child: ElevatedButton(
        onPressed: _nameController.text.isNotEmpty ? _submit : null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: AppTheme.cardColor.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: AppTheme.titleMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('添加药品'),
      ),
    );
  }
}

/// OCR引导步骤条目组件
class _GuideStep extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GuideStep({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 26, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 22, color: AppTheme.textPrimary)),
        ),
      ],
    );
  }
}
