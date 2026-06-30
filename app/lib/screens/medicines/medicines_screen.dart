import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'add_medicine_screen.dart';

/// 药品列表页 — P04
class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的药品')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnDark,
        icon: const Icon(Icons.add, size: 28),
        label: const Text('添加药品'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          Text(
            '共 3 种药品',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.spacingSm),
          // 药品卡片列表（示例数据，后续对接后端）
          _buildMedicationCard(context,
            name: '阿莫西林胶囊',
            dosage: '一粒',
            frequency: '一天两次',
            time: '08:00 / 20:00',
            status: '正常',
          ),
          _buildMedicationCard(context,
            name: '苯磺酸氨氯地平片',
            dosage: '一片',
            frequency: '一天一次',
            time: '12:00',
            status: '正常',
          ),
          _buildMedicationCard(context,
            name: '阿托伐他汀钙片',
            dosage: '一片',
            frequency: '一天一次',
            time: '20:00',
            status: '正常',
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(
    BuildContext context, {
    required String name,
    required String dosage,
    required String frequency,
    required String time,
    required String status,
  }) {
    return Card(
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
                  child: const Icon(Icons.medication, size: 28, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      Text('$dosage · $frequency', style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: AppTheme.bodyMedium,
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text('⏰ $time', style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.warningColor,
            )),
          ],
        ),
      ),
    );
  }
}
