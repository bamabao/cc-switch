import 'dart:math';
import 'package:flutter/material.dart';
import 'clay_bubble_painter.dart';

/// 🎁 积分商城 — 黏土泡泡礼盒
///
/// 绘制一个黏土风格的礼盒（带盖子+蝴蝶结）
class MallPainter extends ClayBubblePainter {
  @override
  String get iconName => 'mall';

  @override
  void paintIcon(Canvas canvas, Size size, Color iconColor) {
    final paint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final s = size.shortestSide;

    // ─── 盒身 ───
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.56),
        width: s * 0.56,
        height: s * 0.46,
      ),
      Radius.circular(s * 0.04),
    );
    canvas.drawRRect(boxRect, paint);

    // ─── 盒盖（圆角矩形，稍大一点） ───
    final lidRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.30),
        width: s * 0.60,
        height: s * 0.22,
      ),
      Radius.circular(s * 0.05),
    );
    canvas.drawRRect(lidRect, paint);

    // ─── 盒盖高光 ───
    final lidShine = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final shineRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx - s * 0.10, size.height * 0.28),
        width: s * 0.18,
        height: s * 0.12,
      ),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(shineRect, lidShine);

    // ─── 蝴蝶结左环 ───
    final bowPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;
    final bowLeft = Path()
      ..moveTo(cx - s * 0.04, size.height * 0.18)
      ..quadraticBezierTo(
        cx - s * 0.28,
        size.height * 0.12,
        cx - s * 0.18,
        size.height * 0.26,
      )
      ..quadraticBezierTo(
        cx - s * 0.10,
        size.height * 0.30,
        cx - s * 0.04,
        size.height * 0.24,
      )
      ..close();
    canvas.drawPath(bowLeft, bowPaint);

    // ─── 蝴蝶结右环 ───
    final bowRight = Path()
      ..moveTo(cx + s * 0.04, size.height * 0.18)
      ..quadraticBezierTo(
        cx + s * 0.28,
        size.height * 0.12,
        cx + s * 0.18,
        size.height * 0.26,
      )
      ..quadraticBezierTo(
        cx + s * 0.10,
        size.height * 0.30,
        cx + s * 0.04,
        size.height * 0.24,
      )
      ..close();
    canvas.drawPath(bowRight, bowPaint);

    // ─── 蝴蝶结中心小圆 ───
    canvas.drawCircle(
      Offset(cx, size.height * 0.22),
      s * 0.04,
      paint,
    );

    // ─── 竖向丝带（穿过盒身） ───
    final ribbonPaint = Paint()
      ..color = iconColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final ribbonV = Rect.fromCenter(
      center: Offset(cx, size.height * 0.56),
      width: s * 0.08,
      height: s * 0.46,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(ribbonV, Radius.circular(s * 0.04)),
      ribbonPaint,
    );

    // ─── 横向丝带 ───
    final ribbonH = Rect.fromCenter(
      center: Offset(cx, size.height * 0.56),
      width: s * 0.56,
      height: s * 0.08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(ribbonH, Radius.circular(s * 0.04)),
      ribbonPaint,
    );

    // ─── 盒身上的星星装饰 ───
    final starPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    _drawStar(canvas, Offset(cx + s * 0.14, size.height * 0.48), s * 0.05, starPaint);
    _drawStar(canvas, Offset(cx - s * 0.10, size.height * 0.62), s * 0.04, starPaint);
    _drawStar(canvas, Offset(cx + s * 0.06, size.height * 0.70), s * 0.035, starPaint);
  }

  /// 绘制四角星
  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final r = (i.isEven) ? size : size * 0.35;
      final angle = i * 0.785398 - 1.5708; // 45° increments, start from top
      final px = center.dx + r * cos(angle);
      final py = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
