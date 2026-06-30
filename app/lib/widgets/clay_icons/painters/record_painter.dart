import 'package:flutter/material.dart';
import 'clay_bubble_painter.dart';

/// 📋 用药记录 — 黏土泡泡剪贴板
///
/// 绘制一个黏土风格的剪贴板+待办清单，内含检查标记
class RecordPainter extends ClayBubblePainter {
  @override
  String get iconName => 'record';

  @override
  void paintIcon(Canvas canvas, Size size, Color iconColor) {
    final paint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final s = size.shortestSide;

    // ─── 剪贴板夹子（顶部小圆角矩形） ───
    final clipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.12),
        width: s * 0.28,
        height: s * 0.12,
      ),
      Radius.circular(s * 0.05),
    );
    canvas.drawRRect(clipRect, paint);

    // ─── 夹子弹簧（两个小竖线） ───
    final springPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - s * 0.08, size.height * 0.08),
      Offset(cx - s * 0.08, size.height * 0.20),
      springPaint,
    );
    canvas.drawLine(
      Offset(cx + s * 0.08, size.height * 0.08),
      Offset(cx + s * 0.08, size.height * 0.20),
      springPaint,
    );

    // ─── 剪贴板主体（圆角矩形大面板） ───
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.50),
        width: s * 0.56,
        height: s * 0.60,
      ),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(boardRect, paint);

    // ─── 面板内部底色（白色半透明，模拟纸张） ───
    final paperPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;
    final paperRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.50),
        width: s * 0.44,
        height: s * 0.48,
      ),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(paperRect, paperPaint);

    // ─── 待办条目（三条横线，代表文字） ───
    final linePaint = Paint()
      ..color = iconColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // 第一条线（已完成 - 带勾）
    final lineY1 = size.height * 0.35;
    canvas.drawLine(
      Offset(cx - s * 0.14, lineY1),
      Offset(cx + s * 0.10, lineY1),
      linePaint,
    );
    // 勾选标记
    final checkPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final checkPath = Path()
      ..moveTo(cx - s * 0.18, lineY1)
      ..lineTo(cx - s * 0.12, lineY1 + s * 0.04)
      ..lineTo(cx - s * 0.02, lineY1 - s * 0.06);
    canvas.drawPath(checkPath, checkPaint);

    // 第二条线
    canvas.drawLine(
      Offset(cx - s * 0.14, size.height * 0.48),
      Offset(cx + s * 0.14, size.height * 0.48),
      linePaint,
    );

    // 第三条线
    canvas.drawLine(
      Offset(cx - s * 0.14, size.height * 0.58),
      Offset(cx + s * 0.06, size.height * 0.58),
      linePaint,
    );

    // ─── 左下角小折角装饰 ───
    final foldPaint = Paint()
      ..color = iconColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final foldPath = Path()
      ..moveTo(cx + s * 0.22, size.height * 0.72)
      ..lineTo(cx + s * 0.14, size.height * 0.72)
      ..lineTo(cx + s * 0.22, size.height * 0.64)
      ..close();
    canvas.drawPath(foldPath, foldPaint);
  }
}
