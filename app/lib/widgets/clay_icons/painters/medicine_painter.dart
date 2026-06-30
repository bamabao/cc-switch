import 'package:flutter/material.dart';
import 'clay_bubble_painter.dart';

/// 💊 药品 — 黏土泡泡胶囊
class MedicinePainter extends ClayBubblePainter {
  @override
  String get iconName => 'medicine';

  @override
  void paintIcon(Canvas canvas, Size size, Color iconColor) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final pillWidth = s * 0.38;
    final pillHeight = s * 0.52;
    final halfWidth = pillWidth / 2;

    // ─── 胶囊上半（深色） ───
    final topPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;
    final topRect = Rect.fromCenter(
      center: Offset(cx, cy - pillHeight * 0.22),
      width: pillWidth,
      height: pillHeight * 0.56,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(topRect, Radius.circular(halfWidth)),
      topPaint,
    );

    // ─── 胶囊下半（浅色半透明） ───
    final bottomPaint = Paint()
      ..color = iconColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final bottomRect = Rect.fromCenter(
      center: Offset(cx, cy + pillHeight * 0.22),
      width: pillWidth,
      height: pillHeight * 0.56,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bottomRect, Radius.circular(halfWidth)),
      bottomPaint,
    );

    // ─── 分割线 ───
    final linePaint = Paint()
      ..color = iconColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - halfWidth * 0.85, cy),
      Offset(cx + halfWidth * 0.85, cy),
      linePaint,
    );

    // ─── 高光 ───
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final shineRect = Rect.fromCenter(
      center: Offset(cx - s * 0.04, cy - pillHeight * 0.22),
      width: pillWidth * 0.3,
      height: pillHeight * 0.35,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shineRect, Radius.circular(pillWidth * 0.15)),
      shinePaint,
    );
  }
}
