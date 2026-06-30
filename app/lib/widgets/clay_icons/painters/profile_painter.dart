import 'package:flutter/material.dart';
import 'clay_bubble_painter.dart';

/// 👤 我的 — 黏土泡泡人物
class ProfilePainter extends ClayBubblePainter {
  @override
  String get iconName => 'profile';

  @override
  void paintIcon(Canvas canvas, Size size, Color iconColor) {
    final paint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final s = size.shortestSide;

    // ─── 头部（圆形） ───
    canvas.drawCircle(
      Offset(cx, size.height * 0.28),
      s * 0.15,
      paint,
    );

    // ─── 身体（圆润梯形，黏土感） ───
    final body = Path()
      ..moveTo(cx - s * 0.28, size.height * 0.42)
      ..quadraticBezierTo(
        cx - s * 0.30,
        size.height * 0.70,
        cx - s * 0.20,
        size.height * 0.82,
      )
      ..lineTo(cx + s * 0.20, size.height * 0.82)
      ..quadraticBezierTo(
        cx + s * 0.30,
        size.height * 0.70,
        cx + s * 0.28,
        size.height * 0.42,
      )
      ..close();
    canvas.drawPath(body, paint);
  }
}
