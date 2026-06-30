import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

/// 积分商城 — 对接后端真实商品API
class MallScreen extends StatefulWidget {
  const MallScreen({super.key});

  @override
  State<MallScreen> createState() => _MallScreenState();
}

class _MallScreenState extends State<MallScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _products = [];
  int _points = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final prodResult = await _api.get(ApiConfig.pointProducts);
      setState(() {
        _products = prodResult['items'] as List<dynamic>? ?? [];
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
      appBar: AppBar(title: const Text('积分商城')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                children: [
                  // 积分余额卡
                  Card(
                    color: AppTheme.primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      child: Column(
                        children: [
                          Text('当前积分',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: AppTheme.textOnDark)),
                          const SizedBox(height: AppTheme.spacingSm),
                          Text('$_points',
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    color: AppTheme.textOnDark,
                                    fontWeight: FontWeight.bold,
                                  )),
                          const SizedBox(height: AppTheme.spacingSm),
                          Text('坚持服药即可获得积分',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text('可兑换商品',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: AppTheme.spacingSm),
                  // 商品列表
                  ..._products.map((p) => _buildProductCard(
                        context,
                        name: p['name'] as String? ?? '',
                        points: p['price_points'] as int? ?? 0,
                        stock: p['stock'] as int? ?? 0,
                      )),
                  if (_products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppTheme.spacingLg),
                      child: Center(
                        child: Text('暂无商品',
                            style: TextStyle(
                                fontSize: AppTheme.bodyLarge,
                                color: AppTheme.textSecondary)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context,
      {required String name, required int points, required int stock}) {
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
          child: const Icon(Icons.card_giftcard,
              size: 36, color: AppTheme.secondaryColor),
        ),
        title: Text(name, style: Theme.of(context).textTheme.titleLarge),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('$points 积分',
                style: const TextStyle(
                    fontSize: AppTheme.titleMedium,
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w600)),
            Text('库存: $stock',
                style: Theme.of(context).textTheme.bodyMedium),
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
