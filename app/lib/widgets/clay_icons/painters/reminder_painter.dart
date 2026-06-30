import 'package:flutter/material.dart';
import 'clay_bubble_painter.dart';

/// ⏰ 提醒 — 黏土泡泡铃铛
class ReminderPainter extends ClayBubblePainter {
  @override
  String get iconName => 'reminder';

  @override
  void paintIcon(Canvas canvas, Size size, Color iconColor) {
    final paint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final s = size.shortestSide;

    // ─── 铃身（倒梯形 + 弧形底） ───
    final bellBody = Path()
      ..moveTo(cx - s * 0.26, size.height * 0.20)
      ..lineTo(cx - s * 0.30, size.height * 0.55)
      ..quadraticBezierTo(
        cx - s * 0.32,
        size.height * 0.68,
        cx - s * 0.22,
        size.height * 0.72,
      )
      ..lineTo(cx + s * 0.22, size.height * 0.72)
      ..quadraticBezierTo(
        cx + s * 0.32,
        size.height * 0.68,
        cx + s * 0.30,
        size.height * 0.55,
      )
      ..lineTo(cx + s * 0.26, size.height * 0.20)
      ..close();
    canvas.drawPath(bellBody, paint);

    // ─── 铃顶半圆 ───
    canvas.drawCircle(
      Offset(cx, size.height * 0.16),
      s * 0.08,
      paint,
    );

    // ─── 铃舌（底部小球） ───
    canvas.drawCircle(
      Offset(cx, size.height * 0.76),
      s * 0.06,
      paint,
    );

    // ─── 铃底开口半透明 ───
    final openPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;
    final openPath = Path()
      ..moveTo(cx - s * 0.15, size.height * 0.72)
      ..lineTo(cx - s * 0.10, size.height * 0.82)
      ..quadraticBezierTo(cx, size.height * 0.86, cx + s * 0.10, size.height * 0.82)
      ..lineTo(cx + s * 0.15, size.height * 0.72)
      ..close();
    canvas.drawPath(openPath, openPaint);
  }
}
