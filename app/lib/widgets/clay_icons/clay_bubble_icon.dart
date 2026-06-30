import 'package:flutter/material.dart';
import 'clay_icon_type.dart';
import 'painters/clay_bubble_painter.dart';
import 'painters/home_painter.dart';
import 'painters/profile_painter.dart';
import 'painters/medicine_painter.dart';
import 'painters/reminder_painter.dart';
import 'painters/record_painter.dart';
import 'painters/voice_painter.dart';
import 'painters/mall_painter.dart';

/// 黏土主题色板
class ClayColors {
  /// 🟠 黏土橙 — 首页 / 我的 / 提醒
  static const Color orange = Color(0xFFFF9F40);

  /// 🟢 黏土绿 — 药品
  static const Color green = Color(0xFF76D160);

  /// 🌿 黏土底绿
  static const Color softGreen = Color(0xFFE6F7DD);

  /// 🌿 药品专用底绿
  static const Color medicineBg = Color(0xFFF0FCE8);

  /// 根据图标类型返回图标颜色
  static Color iconColor(ClayIconType type) => switch (type) {
        ClayIconType.home => orange,
        ClayIconType.profile => orange,
        ClayIconType.medicine => green,
        ClayIconType.reminder => orange,
      ClayIconType.record => green,
      ClayIconType.voice => orange,
      ClayIconType.mall => orange,
      };

  /// 根据图标类型返回背景颜色
  static Color bgColor(ClayIconType type) => switch (type) {
        ClayIconType.home => softGreen,
        ClayIconType.profile => softGreen,
        ClayIconType.medicine => medicineBg,
        ClayIconType.reminder => softGreen,
      ClayIconType.record => medicineBg,
      ClayIconType.voice => softGreen,
      ClayIconType.mall => softGreen,
      };
}

/// 黏土泡泡动画强度
enum ClayAnimationIntensity {
  /// 关闭动画
  none,

  /// 仅 Float 微浮
  subtle,

  /// Float + Squish 弹性点击
  moderate,

  /// 全开：Float + Squish + Pulse 脉冲
  full,
}

/// ClayBubbleIcon — 黏土泡泡风格图标组件
///
/// 适老尺寸：图标 ≥ 64px，交互热区 ≥ 80px
/// 动画：Float 微浮 + Squish 弹性点击 + Pulse 脉冲
///
/// 用法：
/// ```dart
/// ClayBubbleIcon(
///   type: ClayIconType.home,
///   size: 72,
///   onTap: () => print('首页'),
/// )
/// ```
class ClayBubbleIcon extends StatefulWidget {
  /// 图标类型
  final ClayIconType type;

  /// 图标尺寸（宽高相等），默认 72px
  final double size;

  /// 背景圆角，默认 20
  final double cornerRadius;

  /// 点击回调
  final VoidCallback? onTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 动画强度，默认 moderate
  final ClayAnimationIntensity animationIntensity;

  /// 自定义图标颜色覆盖（若 null 则使用 ClayColors）
  final Color? iconColorOverride;

  /// 自定义背景颜色覆盖（若 null 则使用 ClayColors）
  final Color? bgColorOverride;

  const ClayBubbleIcon({
    super.key,
    required this.type,
    this.size = 72,
    this.cornerRadius = 20,
    this.onTap,
    this.onLongPress,
    this.animationIntensity = ClayAnimationIntensity.moderate,
    this.iconColorOverride,
    this.bgColorOverride,
  });

  @override
  State<ClayBubbleIcon> createState() => _ClayBubbleIconState();
}

class _ClayBubbleIconState extends State<ClayBubbleIcon>
    with SingleTickerProviderStateMixin {
  late final ClayBubblePainter _painter;

  // ─── 动画控制器 ───
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Squish 状态
  bool _isPressed = false;

  late final Color _iconColor;
  late final Color _bgColor;

  @override
  void initState() {
    super.initState();

    _painter = _selectPainter(widget.type);
    _iconColor = widget.iconColorOverride ?? ClayColors.iconColor(widget.type);
    _bgColor = widget.bgColorOverride ?? ClayColors.bgColor(widget.type);

    final intensity = widget.animationIntensity;

    // ─── Float 微浮 ───
    if (intensity.index >= ClayAnimationIntensity.subtle.index) {
      _floatCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      );
      _floatAnim = Tween<double>(begin: -3.0, end: 3.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOutSine),
      );
      _floatCtrl.repeat(reverse: true);
    } else {
      _floatCtrl = AnimationController(vsync: this);
      _floatAnim = const AlwaysStoppedAnimation<double>(0.0);
    }

    // ─── Pulse 脉冲 ───
    if (intensity.index >= ClayAnimationIntensity.full.index) {
      _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3000),
      );
      _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine),
      );
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl = AnimationController(vsync: this);
      _pulseAnim = const AlwaysStoppedAnimation<double>(0.0);
    }
  }

  @override
  void didUpdateWidget(ClayBubbleIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      setState(() {
        _painter = _selectPainter(widget.type);
        _iconColor =
            widget.iconColorOverride ?? ClayColors.iconColor(widget.type);
        _bgColor = widget.bgColorOverride ?? ClayColors.bgColor(widget.type);
      });
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  ClayBubblePainter _selectPainter(ClayIconType type) {
    return switch (type) {
      ClayIconType.home => HomePainter(),
      ClayIconType.profile => ProfilePainter(),
      ClayIconType.medicine => MedicinePainter(),
      ClayIconType.reminder => ReminderPainter(),
      ClayIconType.record => RecordPainter(),
      ClayIconType.voice => VoicePainter(),
      ClayIconType.mall => MallPainter(),
    };
  }

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    // ─── 动画层（Float + Pulse + Squish） ───
    Widget iconWidget = AnimatedBuilder(
      animation: Listenable.merge([_floatAnim, _pulseAnim]),
      builder: (context, child) {
        final intensity = widget.animationIntensity;
        final hasAnim = intensity.index >= ClayAnimationIntensity.subtle.index;

        // Float 偏移
        final floatOffset =
            hasAnim ? Offset(0, _floatAnim.value) : Offset.zero;

        // Pulse 缩放（仅 full 模式）
        final pulseScale =
            intensity.index >= ClayAnimationIntensity.full.index
                ? 1.0 + _pulseAnim.value * 0.02
                : 1.0;

        // Squish 弹性点击
        final squishScale = _isPressed ? 0.88 : 1.0;

        return Transform.translate(
          offset: floatOffset,
          child: Transform.scale(
            scale: pulseScale * squishScale,
            child: child,
          ),
        );
      },
      child: _buildBubble(),
    );

    // ─── 适老热区封装 ───
    final hitArea = widget.size < 80 ? 80.0 : widget.size;

    if (widget.onTap != null || widget.onLongPress != null) {
      iconWidget = GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          width: hitArea,
          height: hitArea,
          child: Center(
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: iconWidget,
            ),
          ),
        ),
      );
    }

    return iconWidget;
  }

  /// 构建黏土泡泡本体（无动画，供动画层包装）
  Widget _buildBubble() {
    return CustomPaint(
      painter: _ClayBubblePainterWidget(
        painter: _painter,
        bgColor: _bgColor,
        iconColor: _iconColor,
        cornerRadius: widget.cornerRadius,
      ),
      size: Size(widget.size, widget.size),
    );
  }
}

// ============================================================
// CustomPainter 实现
// ============================================================

class _ClayBubblePainterWidget extends CustomPainter {
  final ClayBubblePainter painter;
  final Color bgColor;
  final Color iconColor;
  final double cornerRadius;

  _ClayBubblePainterWidget({
    required this.painter,
    required this.bgColor,
    required this.iconColor,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制黏土泡泡背景
    ClayBubbleBackground.paint(
      canvas,
      size,
      bgColor,
      cornerRadius: cornerRadius,
    );

    // 绘制图标（留出边距，图标区域 = 总尺寸 - 2×12% padding）
    final iconPad = size.shortestSide * 0.12;
    final iconSize = Size(
      size.width - iconPad * 2,
      size.height - iconPad * 2,
    );
    canvas.save();
    canvas.translate(iconPad, iconPad);
    painter.paintIcon(canvas, iconSize, iconColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ClayBubblePainterWidget oldDelegate) {
    return oldDelegate.painter.iconName != painter.iconName ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.iconColor != iconColor;
  }
}
