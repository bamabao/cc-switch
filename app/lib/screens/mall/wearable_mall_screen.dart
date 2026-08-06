import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

/// 智能穿戴商城（K1系列：手表/指环）
/// 对接后端 ERP：商品展示 + 下单 + 支付确认
class WearableMallScreen extends StatefulWidget {
  const WearableMallScreen({super.key});

  @override
  State<WearableMallScreen> createState() => _WearableMallScreenState();
}

class _WearableMallScreenState extends State<WearableMallScreen> {
  final ApiService _api = ApiService();
  final http.Client _client = http.Client();
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/erp/products');
      final resp = await _client.get(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        setState(() => _products = (data['products'] ?? []).cast<Map<String, dynamic>>());
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _imgUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  Future<void> _buy(Map<String, dynamic> p) async {
    final qtyCtrl = TextEditingController(text: '1');
    final nameCtrl = TextEditingController(text: '用户');
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(p['is_pre_order'] == true ? '🎯 预售下单' : '🛒 立即购买'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p['name']} ¥${p['price']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              if (p['is_pre_order'] == true)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('预售商品，预计${7}天内发货', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                ),
              const SizedBox(height: 12),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '数量', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '收货人', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: addrCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: '收货地址', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('提交订单')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final r = await _api.post('/api/v1/erp/order/create', body: {
          'product_id': p['id'],
          'buyer_name': nameCtrl.text.trim(),
          'buyer_phone': phoneCtrl.text.trim(),
          'buyer_address': addrCtrl.text.trim(),
          'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 1,
        });
        if (!mounted) return;
        final order = r['order'] as Map<String, dynamic>?;
        // 支付确认弹窗
        final payOk = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('💳 确认支付'),
            content: Text('订单 ${order?['order_no']}\n${order?['product_name']} x${order?['quantity']}\n合计：¥${order?['total_amount']}\n\n请使用微信/支付宝扫码支付'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('稍后')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('✅ 已支付')),
            ],
          ),
        );
        if (payOk == true && order != null) {
          await _api.post('/api/v1/erp/order/${order['order_no']}/pay', body: {});
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(p['is_pre_order'] == true ? '🎯 预定成功！到货后发货' : '✅ 支付成功，等待发货'),
                behavior: SnackBarBehavior.floating));
          _load();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('下单失败：$e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⌚ 爸妈宝穿戴设备'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('暂无设备上架'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) => _buildProductCard(_products[i]),
                  ),
                ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final isPre = p['is_pre_order'] == true;
    final stock = p['stock'] as int? ?? 0;
    final features = _parseFeatures(p['features'] as String? ?? '[]');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 产品图
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  _imgUrl(p['image_url'] as String? ?? ''),
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: const Color(0xFFE8F1FA),
                    child: const Center(child: Icon(Icons.watch, size: 64, color: AppTheme.primaryColor)),
                  ),
                ),
              ),
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPre ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(isPre ? '🎯 预售' : '🟢 现货',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name'] ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(p['description'] ?? '',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                if (features.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: features.map((f) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(f, style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('¥${p['price']}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.warningColor)),
                    if ((p['original_price'] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('¥${p['original_price']}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[400], decoration: TextDecoration.lineThrough)),
                      ),
                    const Spacer(),
                    Text(isPre ? '预定${p['reserved']}件' : '库存${stock}件',
                        style: TextStyle(fontSize: 12, color: stock <= (p['min_stock'] ?? 5) && !isPre ? AppTheme.warningColor : Colors.grey[500])),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => _buy(p),
                  style: FilledButton.styleFrom(
                    backgroundColor: isPre ? const Color(0xFFFF9800) : AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(isPre ? '🎯 立即预定' : '🛒 立即购买', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _parseFeatures(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
}
