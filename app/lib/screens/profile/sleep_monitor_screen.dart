import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

/// 睡眠监测页（对标 Oura Ring）
/// 睡眠评分 + 分期分布 + 7天趋势 + 身体基线
class SleepMonitorScreen extends StatefulWidget {
  const SleepMonitorScreen({super.key});

  @override
  State<SleepMonitorScreen> createState() => _SleepMonitorScreenState();
}

class _SleepMonitorScreenState extends State<SleepMonitorScreen> {
  final ApiService _api = ApiService();
  final http.Client _client = http.Client();
  static const int _elderId = 1;

  Map<String, dynamic>? _latest;
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/sleep/history/$_elderId?days=7');
      final resp = await _client.get(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final history = (data['history'] ?? []).cast<Map<String, dynamic>>();
        setState(() {
          _history = history;
          _latest = history.isNotEmpty ? history.first : null;
        });
      }
      final sumUri = Uri.parse('${ApiConfig.baseUrl}/api/v1/sleep/week-summary/$_elderId');
      final sumResp = await _client.get(sumUri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (sumResp.statusCode >= 200 && sumResp.statusCode < 300) {
        _summary = jsonDecode(utf8.decode(sumResp.bodyBytes)) as Map<String, dynamic>;
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _scoreLabel(int score) {
    if (score >= 85) return '优秀';
    if (score >= 70) return '良好';
    if (score >= 60) return '一般';
    if (score >= 45) return '较差';
    return '很差';
  }

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF4CAF50);
    if (score >= 70) return const Color(0xFF8BC34A);
    if (score >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('😴 睡眠监测'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _latest == null
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Icon(Icons.bedtime, size: 72, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Center(child: Text('暂无睡眠数据', style: TextStyle(fontSize: 16, color: AppTheme.textLightGray))),
                        const SizedBox(height: 6),
                        const Center(child: Text('连接爸妈宝Ring/手表自动同步，或让子女帮忙录入', style: TextStyle(fontSize: 13, color: AppTheme.textLightGray))),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildScoreCard(),
                        const SizedBox(height: 14),
                        _buildStagesCard(),
                        const SizedBox(height: 14),
                        _buildTrendCard(),
                        const SizedBox(height: 14),
                        _buildBodyCard(),
                        const SizedBox(height: 14),
                        _buildSummaryCard(),
                        const SizedBox(height: 30),
                      ],
                    ),
            ),
    );
  }

  /// 睡眠评分大卡片
  Widget _buildScoreCard() {
    final l = _latest!;
    final score = l['sleep_score'] as int? ?? 0;
    final total = l['total_minutes'] as int? ?? 0;
    final hours = total ~/ 60;
    final mins = total % 60;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF5C6BC0), const Color(0xFF7986CB)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF5C6BC0).withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          // 评分圆环
          SizedBox(
            width: 92, height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 92, height: 92,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 9,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$score',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('评分', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_scoreLabel(score),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                Text('睡眠时长 $hours小时$mins分',
                    style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 2),
                Text('${l['bedtime'] ?? '--'} 入睡 · ${l['wake_time'] ?? '--'} 醒来',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.75))),
                if ((l['device_model'] as String? ?? '').isNotEmpty)
                  Text('⌚ ${l['device_model']}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 睡眠分期条
  Widget _buildStagesCard() {
    final l = _latest!;
    final deep = l['deep_minutes'] as int? ?? 0;
    final light = l['light_minutes'] as int? ?? 0;
    final rem = l['rem_minutes'] as int? ?? 0;
    final awake = l['awake_minutes'] as int? ?? 0;
    final total = deep + light + rem + awake;
    if (total == 0) return const SizedBox.shrink();

    final deepFrac = deep / total;
    final lightFrac = light / total;
    final remFrac = rem / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('睡眠分期', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          // 分期色条
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  Expanded(flex: (deepFrac * 100).round(), child: Container(color: const Color(0xFF3F51B5))),
                  Expanded(flex: (lightFrac * 100).round(), child: Container(color: const Color(0xFF7986CB))),
                  Expanded(flex: (remFrac * 100).round(), child: Container(color: const Color(0xFFB39DDB))),
                  if (awake > 0) Expanded(flex: (awake / total * 100).round(), child: Container(color: const Color(0xFFE0E0E0))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stageItem('深睡', deep, const Color(0xFF3F51B5)),
              _stageItem('浅睡', light, const Color(0xFF7986CB)),
              _stageItem('REM', rem, const Color(0xFFB39DDB)),
              _stageItem('清醒', awake, const Color(0xFFE0E0E0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stageItem(String label, int minutes, Color color) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('$label', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 2),
          Text('${minutes ~/ 60}h${minutes % 60}m',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  /// 7天趋势
  Widget _buildTrendCard() {
    if (_history.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('近7天睡眠评分', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SleepTrendPainter(history: _history),
            ),
          ),
        ],
      ),
    );
  }

  /// 身体基线
  Widget _buildBodyCard() {
    final l = _latest!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('夜间身体数据', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              _bodyItem('❤️ 平均心率', '${(l['avg_hr'] as num?)?.toStringAsFixed(0) ?? '--'}', '次/分'),
              _bodyItem('📉 最低心率', '${(l['lowest_hr'] as num?)?.toStringAsFixed(0) ?? '--'}', '次/分'),
              _bodyItem('🫁 平均血氧', '${(l['avg_spo2'] as num?)?.toStringAsFixed(0) ?? '--'}', '%'),
              _bodyItem('📈 HRV', '${(l['avg_hrv'] as num?)?.toStringAsFixed(0) ?? '--'}', 'ms'),
            ],
          ),
          const SizedBox(height: 8),
          Text('睡眠效率 ${(l['efficiency'] as num?)?.toStringAsFixed(1) ?? '--'}% · 入睡耗时${l['latency_minutes'] ?? '--'}分钟',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _bodyItem(String label, String value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  /// 周汇总
  Widget _buildSummaryCard() {
    final s = _summary;
    if (s == null || (s['count'] ?? 0) == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('${s['avg_score']}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                const Text('周均评分', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: Column(
              children: [
                Text('${s['avg_minutes'] ~/ 60}h${s['avg_minutes'] % 60}m',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const Text('周均时长', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: Column(
              children: [
                Text('${s['best_score']}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF4CAF50))),
                const Text('最佳一晚', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 7天评分趋势 painter
class _SleepTrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> history;

  _SleepTrendPainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;
    final n = history.length;
    const padding = 12.0;

    final sorted = List<Map<String, dynamic>>.from(history.reversed);

    // 网格
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = padding + (size.height - padding * 2) * i / 4;
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }

    // 折线
    final linePaint = Paint()
      ..color = const Color(0xFF5C6BC0)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final dotPaint = Paint()..color = const Color(0xFF5C6BC0);

    for (var i = 0; i < n; i++) {
      final score = (sorted[i]['sleep_score'] as num?)?.toDouble() ?? 0;
      final x = padding + (size.width - padding * 2) * (n == 1 ? 0.5 : i / (n - 1));
      final y = padding + (size.height - padding * 2) * (1 - (score - 40) / 60); // 40-100范围
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, dotPaint);

      // 日期标签
      final dateStr = (sorted[i]['sleep_date'] as String? ?? '');
      final day = dateStr.length >= 10 ? dateStr.substring(8, 10) : '';
      final label = TextPainter(
        text: TextSpan(text: day, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x - label.width / 2, size.height - 14));
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SleepTrendPainter oldDelegate) => oldDelegate.history != history;
}
