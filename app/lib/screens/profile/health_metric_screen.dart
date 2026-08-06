import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import 'sleep_monitor_screen.dart';

/// 血压/血糖/尿酸/心率等健康指标监测页
/// 手动录入 + 趋势曲线（为穿戴设备数据预留展示）
class HealthMetricScreen extends StatefulWidget {
  const HealthMetricScreen({super.key});

  @override
  State<HealthMetricScreen> createState() => _HealthMetricScreenState();
}

class _HealthMetricScreenState extends State<HealthMetricScreen> {
  final ApiService _api = ApiService();
  final http.Client _client = http.Client();
  static const int _elderId = 1;

  // 指标配置（和后端METRIC_CONFIG对齐）
  static const _metrics = [
    {'type': 'blood_pressure', 'label': '血压', 'icon': '🩺', 'unit': 'mmHg'},
    {'type': 'blood_glucose', 'label': '血糖', 'icon': '🩸', 'unit': 'mmol/L'},
    {'type': 'uric_acid', 'label': '尿酸', 'icon': '🧬', 'unit': 'μmol/L'},
    {'type': 'heart_rate', 'label': '心率', 'icon': '❤️', 'unit': '次/分'},
    {'type': 'spo2', 'label': '血氧', 'icon': '🫁', 'unit': '%'},
    {'type': 'temperature', 'label': '体温', 'icon': '🌡️', 'unit': '℃'},
  ];
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final mt = _metrics[_selectedIndex]['type'];
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/health/history/$_elderId/$mt?days=30');
      final resp = await _client.get(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        setState(() => _data = (data['data'] ?? []).cast<Map<String, dynamic>>());
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showManualInput() async {
    final mt = _metrics[_selectedIndex];
    final valueCtrl = TextEditingController();
    final value2Ctrl = TextEditingController();
    String measureContext = '晨起';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('录入${mt['label']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '数值（${mt['unit']}）',
                hintText: mt['type'] == 'blood_pressure' ? '如 135' : '如 6.2',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (mt['type'] == 'blood_pressure') ...[
              const SizedBox(height: 8),
              TextField(
                controller: value2Ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '舒张压（mmHg）',
                  hintText: '如 85',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: measureContext,
              items: ['晨起', '空腹', '餐后', '睡前', '随机'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => measureContext = v ?? '晨起',
              decoration: InputDecoration(
                labelText: '测量时段',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(valueCtrl.text.trim());
              if (v == null) { return; }
              Navigator.pop(ctx, true);
              _submitManual(v, double.tryParse(value2Ctrl.text.trim()));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _submitManual(double value, double? value2) async {
    final mt = _metrics[_selectedIndex]['type'];
    try {
      await _api.post('/api/v1/health/manual', body: {
        'elder_id': _elderId,
        'metric_type': mt,
        'value': value,
        'value2': value2,
        'context': '晨起',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已记录 ✅'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 健康指标监测'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: '手动录入',
            onPressed: _showManualInput,
          ),
        ],
      ),
      body: Column(
        children: [
          // 指标选择
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('😴', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('睡眠监测', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('评分·分期·时长·趋势', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SleepMonitorScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Text('查看', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF5C6BC0))),
                  ),
                ),
              ],
            ),
          ),
          // 指标选择
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _metrics.length,
              itemBuilder: (ctx, i) {
                final m = _metrics[i];
                final active = i == _selectedIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    _load();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: active ? null : AppTheme.shadowCard,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${m['icon']} ${m['label']}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 趋势图
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _data.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 100),
                              Icon(Icons.timeline, size: 72, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              const Center(child: Text('暂无数据', style: TextStyle(fontSize: 16, color: AppTheme.textLightGray))),
                              const SizedBox(height: 6),
                              const Center(child: Text('点右上角手动录入，或连接穿戴设备自动同步', style: TextStyle(fontSize: 13, color: AppTheme.textLightGray))),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildTrendCard(),
                              const SizedBox(height: 16),
                              ..._data.reversed.map((d) => _buildRecordRow(d)).toList(),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 趋势折线图（CustomPaint，无需第三方库）
  Widget _buildTrendCard() {
    final mt = _metrics[_selectedIndex];
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
          Row(
            children: [
              Text('${mt['icon']} ${mt['label']}趋势',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('共${_data.length}次', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: _TrendChart(
              data: _data,
              showSecondary: mt['type'] == 'blood_pressure',
              unit: mt['unit'] as String,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordRow(Map<String, dynamic> d) {
    final mt = _metrics[_selectedIndex];
    final value = d['value'];
    final value2 = d['value2'];
    final measured = d['measured_at'] as String? ?? '';
    final dateStr = measured.length >= 16 ? '${measured.substring(5, 7)}月${measured.substring(8, 10)}日 ${measured.substring(11, 16)}' : measured;
    final source = d['source'] == 'wearable' ? ' ⌚设备' : ' 📝手动';
    final device = d['device_model'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mt['type'] == 'blood_pressure'
                      ? '${value}/${value2 ?? '?'} ${mt['unit']}'
                      : '$value ${mt['unit']}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                Text('$dateStr$source${device.isNotEmpty ? ' $device' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          if (d['context'] != null && (d['context'] as String).isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${d['context']}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// 简易折线趋势图
class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool showSecondary;
  final String unit;

  const _TrendChart({required this.data, required this.showSecondary, required this.unit});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TrendPainter(data: data, showSecondary: showSecondary, unit: unit),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final bool showSecondary;
  final String unit;

  _TrendPainter({required this.data, required this.showSecondary, required this.unit});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const padding = 16.0;

    // 取主数值范围
    var minV = double.infinity, maxV = double.negativeInfinity;
    for (final d in data) {
      final v = (d['value'] as num).toDouble();
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    if (minV == maxV) { minV -= 1; maxV += 1; }
    final range = maxV - minV;

    // 画网格线
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = padding + (size.height - padding * 2) * i / 4;
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }

    // 画数据点线（主值）
    final n = data.length;
    final mainPaint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final mainPath = Path();
    final dotPaint = Paint()..color = AppTheme.primaryColor;

    // 副值（血压舒张压）
    Paint? secPaint;
    Path? secPath;
    if (showSecondary) {
      secPaint = Paint()
        ..color = AppTheme.secondaryColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      secPath = Path();
    }

    for (var i = 0; i < n; i++) {
      final v = (data[i]['value'] as num).toDouble();
      final x = padding + (size.width - padding * 2) * (n == 1 ? 0.5 : i / (n - 1));
      final y = padding + (size.height - padding * 2) * (1 - (v - minV) / range);
      if (i == 0) mainPath.moveTo(x, y); else mainPath.lineTo(x, y);

      // 副值点
      if (showSecondary && data[i]['value2'] != null) {
        final v2 = (data[i]['value2'] as num).toDouble();
        final y2 = padding + (size.height - padding * 2) * (1 - (v2 - minV) / range);
        if (i == 0) secPath!.moveTo(x, y2); else secPath!.lineTo(x, y2);
      }

      // 圆点
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
    canvas.drawPath(mainPath, mainPaint);
    if (secPath != null && secPaint != null) canvas.drawPath(secPath, secPaint);

    // 最新值标注
    final last = data.last;
    final lastV = (last['value'] as num).toDouble();
    final lx = padding + (size.width - padding * 2) * (n == 1 ? 0.5 : (n - 1) / (n - 1));
    final ly = padding + (size.height - padding * 2) * (1 - (lastV - minV) / range);
    final labelPaint = TextPainter(
      text: TextSpan(
        text: '最新 $lastV$unit',
        style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPaint.paint(canvas, Offset(lx - labelPaint.width - 8, ly - labelPaint.height - 4));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.data != data;
}
