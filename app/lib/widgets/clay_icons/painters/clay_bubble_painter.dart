import 'package:flutter/material.dart';

/// 黏土泡泡图标的基础绘制器（策略模式接口）
abstract class ClayBubblePainter {
  /// 绘制图标主体（黏土泡泡背景由父Widget统一绘制）
  void paintIcon(Canvas canvas, Size size, Color iconColor);

  /// 图标类型名称（用于调试）
  String get iconName;
}

/// 黏土泡泡背景绘制工具方法
class ClayBubbleBackground {
  /// 绘制黏土泡泡背景（圆形/圆角矩形+阴影+高光）
  static void paint(
    Canvas canvas,
    Size size,
    Color fillColor, {
    double cornerRadius = 20,
    double shadowBlur = 6,
    Offset shadowOffset = const Offset(0, 4),
    Color shadowColor = const Color(0x40000000),
  }) {
    final rect = Offset.zero & size;

    // ─── 阴影 ───
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);
    final shadowRect = rect.shift(shadowOffset);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, Radius.circular(cornerRadius)),
      shadowPaint,
    );

    // ─── 主体填充 ───
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)),
      fillPaint,
    );

    // ─── 左上高光（黏土感） ───
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final highlightPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.4, 0)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.2,
        0,
        size.height * 0.3,
      )
      ..close();
    canvas.drawPath(highlightPath, highlightPaint);
  }
}
