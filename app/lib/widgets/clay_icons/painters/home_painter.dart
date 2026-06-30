import 'package:flutter/material.dart';
import 'clay_bubble_painter.dart';

/// 🏠 首页 — 黏土泡泡房子
class HomePainter extends ClayBubblePainter {
  @override
  String get iconName => 'home';

  @override
  void paintIcon(Canvas canvas, Size size, Color iconColor) {
    final paint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.shortestSide;

    // ─── 屋顶（三角形） ───
    final roof = Path()
      ..moveTo(cx, cy - s * 0.30)
      ..lineTo(cx + s * 0.30, cy - s * 0.02)
      ..lineTo(cx + s * 0.30, cy + s * 0.10)
      ..lineTo(cx - s * 0.30, cy + s * 0.10)
      ..lineTo(cx - s * 0.30, cy - s * 0.02)
      ..close();
    canvas.drawPath(roof, paint);

    // ─── 墙体（圆角矩形） ───
    final wallRect = Rect.fromCenter(
      center: Offset(cx, cy + s * 0.18),
      width: s * 0.48,
      height: s * 0.32,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(wallRect, const Radius.circular(4)),
      paint,
    );

    // ─── 门（小圆角矩形，半透明） ───
    final doorRect = Rect.fromCenter(
      center: Offset(cx, cy + s * 0.22),
      width: s * 0.14,
      height: s * 0.20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(doorRect, const Radius.circular(3)),
      Paint()..color = iconColor.withValues(alpha: 0.3),
    );
  }
}
