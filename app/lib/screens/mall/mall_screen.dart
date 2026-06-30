import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// 商城首页 — P12
class MallScreen extends StatelessWidget {
  const MallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('积分商城')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          // ── 积分余额卡 ──
          Card(
            color: AppTheme.primaryColor,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                children: [
                  Text(
                    '当前积分',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textOnDark,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    '1,280',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppTheme.textOnDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    '坚持服药即可获得积分',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacingLg),
          Text('可兑换商品', style: Theme.of(context).textTheme.headlineMedium),

          // ── 商品列表 ──
          _buildProductCard(context,
            name: '维达抽纸一提',
            points: 200,
            stock: 50,
          ),
          _buildProductCard(context,
            name: '福临门食用油 1.8L',
            points: 500,
            stock: 20,
          ),
          _buildProductCard(context,
            name: '东北大米 5kg',
            points: 800,
            stock: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context, {
    required String name,
    required int points,
    required int stock,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.spacingMd),
        leading: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: const Icon(Icons.card_giftcard, size: 36, color: AppTheme.secondaryColor),
        ),
        title: Text(name, style: Theme.of(context).textTheme.titleLarge),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('$points 积分', style: TextStyle(
              fontSize: AppTheme.titleMedium,
              color: AppTheme.warningColor,
              fontWeight: FontWeight.w600,
            )),
            Text('库存: $stock', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: stock > 0 ? () {} : null,
          child: Text(stock > 0 ? '兑换' : '已兑完',
            style: const TextStyle(fontSize: AppTheme.bodyLarge)),
        ),
      ),
    );
  }
}
