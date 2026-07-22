import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/reminder_service.dart';
import '../../widgets/time_slot_selector.dart';
import '../../widgets/reminder_dialog.dart';
import '../../models/medication_dose.dart';
import '../voice/voice_screen.dart';
import 'medicine_camera_screen.dart';

/// 药品录入页 — 三通道录入 + 每时段独立服药数量
///
/// v3.8 改造：
/// - 每时段独立「数量 + 单位 + 时间」输入（支持小数半片）
/// - 柔和轻拟物视觉升级（方案A）：大圆角+弱阴影+低饱和渐变+卡片悬浮
/// - 统一圆角规范：大卡22-28px、按钮16-20px、输入框12-16px
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

  // ─── 每时段独立剂量数据（由TimeSlotSelector回传） ───
  List<TimeSlotData> _timeSlotDataList = [];

  // 用户已确认的提醒配置
  MedicationDose? _confirmedDose;

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
  static const Map<String, String> _unitNormalizeMap = {
    'g': '克 (g)', '克': '克 (g)',
    'mg': '毫克 (mg)', '毫克': '毫克 (mg)',
    'ml': '毫升 (ml)', 'mL': '毫升 (ml)', '毫升': '毫升 (ml)',
  };

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final user = await _api.getMe();
      if (mounted) setState(() => _elderId = user.id);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// 将OCR识别的剂量字符串（如 "0.5g" "2粒"）拆分为首时段用量
  void _parseOcrDosage(String dosageStr) {
    if (dosageStr.isEmpty || _timeSlotDataList.isEmpty) return;
    final match = RegExp(r'^(\d+\.?\d*)\s*(.+)$').firstMatch(dosageStr.trim());
    if (match != null) {
      final number = match.group(1)!;
      var unit = _unitNormalizeMap[match.group(2)!.trim()] ?? match.group(2)!.trim();
      setState(() {
        _timeSlotDataList = _timeSlotDataList.map((d) =>
          TimeSlotData(time: d.time, dosage: number, unit: unit)
        ).toList();
      });
    }
  }

  // ─── 提交：药品 + 每时段调度 + 提醒 ───

  void _submit() async {
    if (_submitting || _nameController.text.trim().isEmpty) return;

    // 校验：至少有一条时段
    if (_timeSlotDataList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少添加一个服药时间'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 校验：每个时段的数量不能为空
    for (int i = 0; i < _timeSlotDataList.length; i++) {
      final d = _timeSlotDataList[i];
      if (d.dosage.trim().isEmpty || double.tryParse(d.dosage) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请填写第 ${i + 1} 个时段的服药数量'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);

    try {
      // Step 1: 提交药品 + 每时段调度到后端
      final schedules = _timeSlotDataList.map((d) => {
        'time_of_day': '${d.time.hour.toString().padLeft(2, '0')}:${d.time.minute.toString().padLeft(2, '0')}',
        'dosage': double.tryParse(d.dosage) ?? 1.0,
        'dosage_display': '${d.dosage}${d.unit}',
        'weekday_mask': 127,
      }).toList();

      final response = await _api.post(
        '${ApiConfig.medications}?elder_id=$_elderId',
        body: {
          'name': _nameController.text.trim(),
          'category': _categoryApiMap[_selectedCategory] ?? 'oral',
          'oral_form': 'tablet',
          // 第一时段用量作为 medication 级默认值（兼容旧字段）
          'dosage_per_take': double.tryParse(_timeSlotDataList.first.dosage) ?? 1.0,
          'unit': _timeSlotDataList.first.unit.replaceAll(RegExp(r'\s*\(.+\)'), ''),
          'frequency_per_day': _timeSlotDataList.length,
          'notes': _noteController.text.trim(),
          'status': 'approved',
          'schedules': schedules,
        },
      );

      if (!mounted) return;
      final medicationId = response['id'] as int? ?? 0;

      // Step 2: 提醒方式弹窗
      final MedicationDose? dose = _confirmedDose ?? await showDialog<MedicationDose>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ReminderDialog(
          medicationName: _nameController.text.trim(),
          onConfirm: (d) => Navigator.pop(ctx, d),
        ),
      );

      if (!mounted || dose == null) return;

      // Step 3: 保存提醒到后端（用首时段用量信息）
      final doseWithSlots = dose.copyWith(
        dosageAmount: _timeSlotDataList.first.dosage,
        dosageUnit: _timeSlotDataList.first.unit,
        frequencyPerDay: _timeSlotDataList.length,
        timeSlots: _timeSlotDataList.map((d) => d.time).toList(),
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

  void _readPageAloud() {
    final doses = _timeSlotDataList.map((d) =>
      '${d.dosage}${d.unit} ${d.time.hour.toString().padLeft(2, '0')}:${d.time.minute.toString().padLeft(2, '0')}'
    ).join('，');
    final text = '药品名称：${_nameController.text}，'
        '每次服用：$doses，'
        '注意事项：${_noteController.text}';
    ReminderService.readPageText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: _buildSoftAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.bgGradientTop,
              AppTheme.bgGradientBottom,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 三通道入口 — 悬浮卡片
              _buildInputChannels(),
              const SizedBox(height: 20),

              // 分类选择
              _buildCategorySelector(),
              const SizedBox(height: 20),

              // 表单
              if (_showForm) _buildForm(),
              if (_showForm) const SizedBox(height: 20),

              // 服用时间（每时段独立数量+单位+时间）
              if (_showForm) ...[
                _buildTimeSlotSection(),
                const SizedBox(height: 20),
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  方案A 柔和轻拟物组件
  // ═══════════════════════════════════════════════════════

  /// 顶部导航栏 — 高橙色渐变 + 弥散阴影 + 内边距增大
  PreferredSizeWidget _buildSoftAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(84),
      child: Container(
        margin: const EdgeInsets.only(top: 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryLight, AppTheme.primaryColor, AppTheme.primaryDark],
            stops: [0.0, 0.4, 1.0],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: [
            // 顶部高光
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.2),
              blurRadius: 2,
              offset: const Offset(0, -1),
            ),
            // 主下沉弥散阴影
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            // 底部紧密阴影
            BoxShadow(
              color: AppTheme.primaryDark.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textOnDark, size: 26),
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(12),
                ),
                const Spacer(),
                const Text(
                  '添加药品',
                  style: TextStyle(
                    fontSize: AppTheme.titleLarge,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textOnDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: AppTheme.textOnDark, size: 28),
                  onPressed: _readPageAloud,
                  tooltip: '朗读页面文字',
                  padding: const EdgeInsets.all(12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 三通道入口 — 独立悬浮卡片 + 米白底色 + 图标投影
  Widget _buildInputChannels() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildChannelCard(
          icon: Icons.camera_alt,
          label: '拍照',
          subtitle: '拍药盒自动识别',
          color: AppTheme.primaryColor,
          onTap: () => _onCameraTap(),
        )),
        const SizedBox(width: 14),
        Expanded(child: _buildChannelCard(
          icon: Icons.mic,
          label: '语音录入',
          subtitle: '说话填写药品信息',
          color: AppTheme.secondaryColor,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceScreen()));
          },
        )),
        const SizedBox(width: 14),
        Expanded(child: _buildChannelCard(
          icon: Icons.edit,
          label: '手动填写',
          subtitle: '自己输入药品信息',
          color: const Color(0xFF1565C0),
          onTap: () => _nameFocus.requestFocus(),
        )),
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
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFCF9F0), // 极浅米白
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: [
            // 主悬浮阴影
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            // 底部紧阴影
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 图标 — 带浅投影
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 22,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCameraTap() async {
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

              if (name.isNotEmpty) _nameController.text = name;
              if (dosage.isNotEmpty) _parseOcrDosage(dosage);
              if (frequency.isNotEmpty) {
                // frequency 仅用于提示，不再设每日频次
              }
              if (rawTexts.isNotEmpty && _noteController.text.isEmpty) {
                _noteController.text = rawTexts.join(' ');
              }

              if (success && name.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已自动填入：$name${dosage.isNotEmpty ? "，用量：$dosage" : ""}'),
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
              if (mounted) setState(() {});
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
  }

  /// 分类选择 — 选中态：橙色渐变+外发光；未选中：浅灰+内阴影凹陷
  Widget _buildCategorySelector() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.category, color: AppTheme.primaryColor, size: 26),
              SizedBox(width: 8),
              Text(
                '药品分类',
                style: TextStyle(
                  fontSize: AppTheme.bodyLarge,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              _categories.length,
              (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = _categories[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: _selectedCategory == _categories[i]
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppTheme.primaryLight, AppTheme.primaryColor],
                              )
                            : null,
                        color: _selectedCategory == _categories[i]
                            ? null
                            : const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                        border: Border.all(
                          color: _selectedCategory == _categories[i]
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        boxShadow: _selectedCategory == _categories[i]
                            ? [
                                // 选中态：外发光柔光阴影
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                // 未选中态：微凹陷效果
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                              ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _categoryIcons[i],
                            color: _selectedCategory == _categories[i]
                                ? Colors.white
                                : AppTheme.textSecondary,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _categories[i],
                            style: TextStyle(
                              fontSize: AppTheme.bodySmall,
                              color: _selectedCategory == _categories[i]
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
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
    );
  }

  /// 表单卡片 — 药品名称 + 注意事项
  Widget _buildForm() {
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
        Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: large ? 26 : AppTheme.bodyLarge,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: large ? 12 : 8),
        // 外层凹槽效果
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F0),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              // 内嵌凹槽效果
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
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
                fontSize: large ? 24 : AppTheme.titleMedium,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  /// 服用时间 — 每时段独立数量+单位+时间
  Widget _buildTimeSlotSection() {
    return TimeSlotSelector(
      timeSlots: _timeSlotDataList,
      onChanged: (dataList) => setState(() => _timeSlotDataList = dataList),
    );
  }

  /// 提交按钮 — 橙色渐变 + 阴影悬浮
  Widget _buildSubmitButton() {
    return SizedBox(
      height: AppTheme.buttonHeight,
      child: GestureDetector(
        onTap: _nameController.text.isNotEmpty ? _submit : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: _nameController.text.isNotEmpty
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryLight, AppTheme.primaryColor, AppTheme.primaryDark],
                    stops: [0.0, 0.4, 1.0],
                  )
                : null,
            color: _nameController.text.isNotEmpty ? null : AppTheme.cardColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            boxShadow: _nameController.text.isNotEmpty
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppTheme.primaryDark.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '添加药品',
            style: TextStyle(
              fontSize: AppTheme.titleMedium,
              fontWeight: FontWeight.w600,
              color: _nameController.text.isNotEmpty ? AppTheme.textOnDark : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// OCR引导步骤条目组件
class _GuideStep extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GuideStep({required this.icon, required this.text});

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
