import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

/// 药品详情页 — 说明书、忌口、使用注意事项
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
  bool _loading = true;
  int _elderId = 1;

  @override
  void initState() {
    super.initState();
    _loadDetail();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: Text(widget.medicationName, style: const TextStyle(fontSize: AppTheme.titleLarge)),
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
                      const SizedBox(height: AppTheme.spacingMd),
                      _buildScheduleCard(),
                      const SizedBox(height: AppTheme.spacingMd),
                      _buildNotesCard(),
                    ],
                  ),
                ),
    );
  }

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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(Icons.access_time, color: AppTheme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    time.substring(0, 5),
                    style: const TextStyle(fontSize: AppTheme.titleMedium, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                  ),
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
    const labels = {
      'oral': '内服',
      'external': '外用',
      'injection': '针剂',
      'supplement': '滋补',
    };
    return labels[category] ?? category;
  }
}
