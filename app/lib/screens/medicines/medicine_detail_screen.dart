import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../widgets/ai_chat_dialog.dart';
import 'add_medicine_screen.dart';

/// 药品详情页 — 说明书、用法用量、禁忌、注意事项
class MedicineDetailScreen extends StatefulWidget {
  final int medicationId;
  final String medicationName;

  const MedicineDetailScreen({
    super.key,
    required this.medicationId,
    required this.medicationName,
  });

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _medication;
  Map<String, dynamic>? _drugInfo;
  bool _loading = true;
  bool _drugLoading = false;
  int _elderId = 1;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _searchDrugInfo();
  }

  Future<void> _loadDetail() async {
    try {
      try {
        final user = await _api.getMe();
        _elderId = user.id;
      } catch (_) {}

      final result = await _api.get(
        '${ApiConfig.medications}/${widget.medicationId}',
        queryParams: {'elder_id': '$_elderId', 'token': _api.token ?? ''},
      );

      if (!mounted) return;
      setState(() {
        _medication = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _searchDrugInfo() async {
    setState(() => _drugLoading = true);
    try {
      final result = await _api.searchDrugInstruction(widget.medicationName);
      final items = result['items'] as List<dynamic>? ?? [];
      if (items.isNotEmpty && items[0] is Map && items[0].isNotEmpty) {
        _drugInfo = items[0] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('药品说明书搜索失败: $e');
    }
    if (mounted) setState(() => _drugLoading = false);
  }

  /// 导航到编辑页
  Future<void> _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicineScreen(
          editMedication: _medication,
        ),
      ),
    );
    if (result == true && mounted) {
      _loadDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: Text(widget.medicationName, style: const TextStyle(fontSize: AppTheme.titleLarge)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
            onPressed: _navigateToEdit,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _medication == null
              ? const Center(child: Text('加载失败', style: TextStyle(fontSize: AppTheme.titleMedium)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 12),
                      _buildScheduleCard(),
                      const SizedBox(height: 12),
                      _buildDrugInstructionCard(),
                      const SizedBox(height: 12),
                      _buildAiChatButton(),
                      const SizedBox(height: 12),
                      _buildNotesCard(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  // ─── 基本信息卡片 ───
  Widget _buildInfoCard() {
    final m = _medication!;
    final dosagePerTake = m['dosage_per_take'];
    final unit = m['unit'] as String? ?? '';
    final frequency = m['frequency_per_day'];
    final category = m['category'] as String? ?? '';
    final mealRelation = m['meal_relation'] as String? ?? '';

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
          const Text('💊 药品信息', style: TextStyle(fontSize: AppTheme.headlineMedium, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppTheme.spacingMd),
          _infoRow('药品名称', widget.medicationName),
          if (dosagePerTake != null) _infoRow('单次剂量', '$dosagePerTake $unit'),
          if (frequency != null) _infoRow('每日频次', '$frequency 次'),
          if (category.isNotEmpty) _infoRow('分类', _categoryLabel(category)),
          if (mealRelation.isNotEmpty) _infoRow('服用方式', mealRelation),
        ],
      ),
    );
  }

  // ─── 服药时间卡片 ───
  Widget _buildScheduleCard() {
    final schedules = _medication!['schedules'] as List<dynamic>? ?? [];
    if (schedules.isEmpty) return const SizedBox.shrink();

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
          const Text('⏰ 服药时间', style: TextStyle(fontSize: AppTheme.headlineMedium, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppTheme.spacingMd),
          ...schedules.map((s) {
            final time = s['time_of_day'] as String? ?? '';
            final doseDisplay = s['dosage_display'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(Icons.access_time, color: AppTheme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text(time.length >= 5 ? time.substring(0, 5) : time,
                    style: const TextStyle(fontSize: AppTheme.titleMedium, color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  if (doseDisplay.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(doseDisplay, style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 说明书卡片（核心新增）───
  Widget _buildDrugInstructionCard() {
    if (_drugLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.shadowCard,
        ),
        child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_drugInfo == null) return const SizedBox.shrink();

    final d = _drugInfo!;
    final hasContent = [
      d['adult_dosage'], d['child_dosage'], d['elderly_dosage'],
      d['contraindications'], d['side_effects'], d['dietary_restrictions'],
      d['allergy_warning'], d['full_instruction'],
    ].any((v) => v != null && v.toString().isNotEmpty);

    if (!hasContent) return const SizedBox.shrink();

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
              const Text('📖 标准说明书', style: TextStyle(fontSize: AppTheme.headlineMedium, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => _openOnline(d['medicine_name'] as String? ?? widget.medicationName),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 14, color: AppTheme.primaryColor),
                      SizedBox(width: 4),
                      Text('查看原文', style: TextStyle(fontSize: 14, color: AppTheme.primaryColor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 用法用量分段
          _sectionTitle('👤 成人用量'),
          _sectionContent(d['adult_dosage'] ?? '遵医嘱'),

          if ((d['child_dosage'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionTitle('🧒 儿童用量'),
            _sectionContent(d['child_dosage']!),
          ],

          if ((d['elderly_dosage'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionTitle('👴 老年/特殊人群'),
            _sectionContent(d['elderly_dosage']!),
          ],

          if ((d['meal_relation'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionTitle('🍽️ 服用方式'),
            _sectionContent(d['meal_relation']!),
          ],

          // 适应症
          if ((d['indications'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionTitle('🩺 适应症'),
            _sectionContent(d['indications']!),
          ],

          // 注意事项
          if ((d['precautions'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionTitle('📋 注意事项'),
            _sectionContent(d['precautions']!, isWarning: true),
          ],

          // 禁忌与注意
          if ((d['contraindications'] ?? '').isNotEmpty) ...[
            const Divider(height: 20),
            _sectionTitle('⚠️ 禁忌'),
            _sectionContent(d['contraindications']!, isWarning: true),
          ],

          if ((d['side_effects'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionTitle('💊 不良反应'),
            _sectionContent(d['side_effects']!),
          ],

          if ((d['dietary_restrictions'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionTitle('🚫 饮食禁忌'),
            _sectionContent(d['dietary_restrictions']!),
          ],

          if ((d['allergy_warning'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionTitle('🔔 过敏警示'),
            _sectionContent(d['allergy_warning']!, isWarning: true),
          ],

          // 完整说明书（折叠）
          if ((d['full_instruction'] ?? '').isNotEmpty) ...[
            const Divider(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('📄 完整说明书', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(d['full_instruction']!, style: const TextStyle(fontSize: 16, height: 1.6, color: AppTheme.textPrimary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary));
  }

  Widget _sectionContent(String content, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 17,
          height: 1.4,
          color: isWarning ? const Color(0xFFE53935) : AppTheme.textSecondary,
          fontWeight: isWarning ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
    );
  }

  /// 在线搜索药品说明书
  Future<void> _openOnline(String name) async {
    final query = Uri.encodeComponent(name);
    final urls = [
      'https://dayi.org.cn/search?keyword=$query',
      'https://drugs.dxy.cn/search?keyword=$query',
    ];
    for (final url in urls) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return;
      }
    }
  }

  // ─── 备注卡片 ───
  Widget _buildNotesCard() {
    final notes = _medication!['notes'] as String? ?? '';
    final dietary = _medication!['dietary_restrictions'] as String? ?? '';
    final sideEffects = _medication!['side_effects'] as String? ?? '';

    if (notes.isEmpty && dietary.isEmpty && sideEffects.isEmpty) {
      return const SizedBox.shrink();
    }

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
          const Text('📋 注意事项', style: TextStyle(fontSize: AppTheme.headlineMedium, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppTheme.spacingMd),
          if (notes.isNotEmpty) _infoRow('备注', notes),
          if (dietary.isNotEmpty) _infoRow('饮食忌口', dietary),
          if (sideEffects.isNotEmpty) _infoRow('不良反应', sideEffects),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: AppTheme.titleMedium, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category) {
    const labels = {'oral': '内服', 'external': '外用', 'injection': '针剂', 'supplement': '滋补'};
    return labels[category] ?? category;
  }

  /// AI 智能用药问答按钮
  Widget _buildAiChatButton() {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AiChatDialog(
          drugName: widget.medicationName,
          medicationName: widget.medicationName,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFFFF7043)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI 用药助手', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text('问用法、禁忌、注意事项…', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
