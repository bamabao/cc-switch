import 'package:flutter/material.dart';
import 'clay_bubble_painter.dart';

/// 🎤 语音 — 黏土泡泡麦克风
///
/// 绘制一个黏土风格的麦克风+声波动画图形
class VoicePainter extends ClayBubblePainter {
  @override
  String get iconName => 'voice';

  @override
  void paintIcon(Canvas canvas, Size size, Color iconColor) {
    final paint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final s = size.shortestSide;

    // ─── 麦克风头（圆角胶囊体） ───
    final micHeadRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.32),
        width: s * 0.30,
        height: s * 0.38,
      ),
      Radius.circular(s * 0.15),
    );
    canvas.drawRRect(micHeadRect, paint);

    // ─── 麦克风头高光 ───
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;
    final shineRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx - s * 0.04, size.height * 0.28),
        width: s * 0.10,
        height: s * 0.20,
      ),
      Radius.circular(s * 0.05),
    );
    canvas.drawRRect(shineRect, shinePaint);

    // ─── 麦克风支架（圆弧过渡到底座） ───
    final standPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;
    final standPath = Path()
      ..moveTo(cx - s * 0.06, size.height * 0.52)
      ..quadraticBezierTo(
        cx - s * 0.10,
        size.height * 0.60,
        cx - s * 0.16,
        size.height * 0.70,
      )
      ..lineTo(cx + s * 0.16, size.height * 0.70)
      ..quadraticBezierTo(
        cx + s * 0.10,
        size.height * 0.60,
        cx + s * 0.06,
        size.height * 0.52,
      )
      ..close();
    canvas.drawPath(standPath, standPaint);

    // ─── 底座（半椭圆） ───
    final baseRect = Rect.fromCenter(
      center: Offset(cx, size.height * 0.78),
      width: s * 0.44,
      height: s * 0.14,
    );
    canvas.drawOval(baseRect, paint);

    // ─── 声波弧线（左侧两条） ───
    final wavePaint = Paint()
      ..color = iconColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // 内弧
    final innerArc = Path()
      ..moveTo(cx - s * 0.24, size.height * 0.24)
      ..quadraticBezierTo(
        cx - s * 0.30,
        size.height * 0.32,
        cx - s * 0.24,
        size.height * 0.40,
      );
    canvas.drawPath(innerArc, wavePaint);

    // 外弧
    final outerWave = Paint()
      ..color = iconColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final outerPath = Path()
      ..moveTo(cx - s * 0.32, size.height * 0.18)
      ..quadraticBezierTo(
        cx - s * 0.42,
        size.height * 0.32,
        cx - s * 0.32,
        size.height * 0.46,
      );
    canvas.drawPath(outerPath, outerWave);
  }
}
