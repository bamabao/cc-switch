import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../medicines/medicines_screen.dart';
import '../voice/voice_screen.dart';

/// 首页 / Dashboard — P03
///
/// 适老化设计：超大字体、高对比卡片、核心功能一目了然
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('爸妈宝'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 32),
            onPressed: () {},
            tooltip: '消息',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 头部问候 ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '早上好！🌅',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      '今天还有 3 次药需要服用',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // ── 语音快捷入口 ──
            SizedBox(
              height: 120,
              child: Card(
                color: AppTheme.primaryColor,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VoiceScreen()),
                    );
                  },
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic, size: 56, color: AppTheme.textOnDark),
                        SizedBox(width: AppTheme.spacingMd),
                        Text(
                          '对我说 "帮我看看今天的药"',
                          style: TextStyle(
                            fontSize: AppTheme.titleMedium,
                            color: AppTheme.textOnDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // ── 今日用药列表 ──
            Text(
              '📋 今日用药',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppTheme.spacingSm),

            const _MedicationCard(
              name: '阿莫西林胶囊',
              dosage: '一粒',
              time: '08:00',
              status: '已服',
              statusColor: AppTheme.secondaryColor,
            ),
            const _MedicationCard(
              name: '苯磺酸氨氯地平片',
              dosage: '一片',
              time: '12:00',
              status: '待服',
              statusColor: AppTheme.warningColor,
            ),
            const _MedicationCard(
              name: '阿托伐他汀钙片',
              dosage: '一片',
              time: '20:00',
              status: '待服',
              statusColor: AppTheme.warningColor,
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // ── 查看全部 ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MedicinesScreen()),
                  );
                },
                icon: const Icon(Icons.medication, size: 28),
                label: const Text('查看全部药品'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条用药卡片
class _MedicationCard extends StatelessWidget {
  final String name;
  final String dosage;
  final String time;
  final String status;
  final Color statusColor;

  const _MedicationCard({
    required this.name,
    required this.dosage,
    required this.time,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: const Icon(Icons.medication, size: 32, color: AppTheme.primaryColor),
        ),
        title: Text(name, style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text('$dosage · $time', style: Theme.of(context).textTheme.bodyLarge),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: AppTheme.bodyMedium,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
        onTap: () {},
      ),
    );
  }
}
