import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import 'add_medicine_screen.dart';
import 'record_screen.dart';

/// 药品列表页 — 对接后端真实API
class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _medications = [];
  bool _loading = true;
  String? _error;
  int _elderId = 0;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    try {
      final user = await _api.getMe();
      if (mounted) setState(() => _elderId = user.id);
    } catch (_) {}
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    if (_elderId == 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.get(ApiConfig.medications, queryParams: {
        'elder_id': '$_elderId',
        'token': _api.token ?? '',
      });
      setState(() {
        _medications = result['items'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '加载失败，请下拉刷新重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的药品'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordScreen()),
            ),
            tooltip: '用药记录',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
          );
          _loadMedications();
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnDark,
        icon: const Icon(Icons.add, size: 28),
        label: const Text('添加药品'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(fontSize: AppTheme.bodyLarge)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMedications,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_medications.isEmpty) {
      return const Center(
        child: Text('还没有药品，点击右下角添加',
            style: TextStyle(fontSize: AppTheme.bodyLarge)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMedications,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          Text(
            '共 ${_medications.length} 种药品',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.spacingSm),
          ..._medications.map((med) => _buildMedicationCard(context, med)),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(BuildContext context, dynamic med) {
    final name = med['name'] as String? ?? '';
    final category = med['category'] as String? ?? 'oral';
    final schedules = med['schedules'] as List<dynamic>? ?? [];
    // 每时段独立剂量+时间展示
    final timeInfos = schedules.map((s) {
      final t = s['time_of_day'] as String? ?? '';
      final tStr = t.length >= 5 ? t.substring(0, 5) : t;
      final doseDisplay = s['dosage_display'] as String? ?? '';
      if (doseDisplay.isNotEmpty) return '$tStr $doseDisplay';
      return tStr;
    }).where((s) => s.isNotEmpty).join('  ');

    // 图标表情
    final iconMap = {'oral': '💊', 'external': '🧴', 'injection': '💉', 'supplement': '🌿'};
    final emoji = iconMap[category] ?? '💊';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => _showMedicationDetail(context, med, emoji, timeInfos),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleLarge),
                        if (timeInfos.isNotEmpty)
                          Text(timeInfos, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.primaryColor)),
                      ],
                    ),
                  ),
                ],
              ),
              if (timeInfos.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingSm),
                Text('⏰ $timeInfos',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: AppTheme.warningColor)),
              ],
              if (med['notes'] != null && (med['notes'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('📝 ${med['notes']}',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppTheme.textSecondary)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMedicationDetail(BuildContext ctx, dynamic med, String emoji, String timeInfos) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) {
        final name = med['name'] as String? ?? '';
        final manufacturer = med['manufacturer'] as String? ?? '';

        final dosagePerTake = med['dosage_per_take'];
        final frequency = med['frequency_per_day'];
        final totalQty = med['total_quantity']?.toString() ?? '';
        final unit = med['unit'] as String? ?? '';
        final expiry = med['expiry_date']?.toString() ?? '';
        final notes = med['notes'] as String? ?? '';
        final sideEffects = med['side_effects'] as String? ?? '';
        final dietaryRestricts = med['dietary_restrictions'] as String? ?? '';
        final mealRelation = med['meal_relation'] as String? ?? '';

        return AlertDialog(
          title: Row(
            children: [
              Text('$emoji ', style: const TextStyle(fontSize: 24)),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timeInfos.isNotEmpty) _detailRow('服用时间', timeInfos),
                if (manufacturer.isNotEmpty) _detailRow('厂家', manufacturer),
                if (dosagePerTake != null) _detailRow('每次用量', '$dosagePerTake$unit'),
                if (frequency != null) _detailRow('每日次数', '${frequency}次'),
                if (totalQty.isNotEmpty) _detailRow('总量', '$totalQty$unit'),
                if (expiry.isNotEmpty) _detailRow('有效期', expiry),
                if (mealRelation.isNotEmpty) _detailRow('餐前/餐后', mealRelation),
                if (dietaryRestricts.isNotEmpty) _detailRow('饮食禁忌', dietaryRestricts),
                if (sideEffects.isNotEmpty) _detailRow('副作用', sideEffects),
                if (notes.isNotEmpty) _detailRow('备注', notes),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
              label: const Text('删除', style: TextStyle(color: AppTheme.dangerColor)),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _deleteMedication(ctx, med['id'] as int, med['name'] as String? ?? '');
              },
            ),
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('关闭')),
          ],
        );
      },
    );
  }

  Future<void> _deleteMedication(BuildContext ctx, int medicationId, String name) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除「$name」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _api.deleteMedication(medicationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🗑️ 已删除「$name」')),
      );
      _loadMedications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }



  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label：', style: const TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: AppTheme.bodyMedium, color: color ?? AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
