import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';

/// 3D 黏土风格圆形打卡按钮
/// ─────────────────────────
/// 未服药：低饱和珊瑚红 (0xFFF87670)，无图标
/// 已服药：护眼薄荷绿 (0xFF59C992)，白色 Icons.check (size=36)
/// 内建点击缩放回弹动画与震动反馈，再次点击可撤销
class ClayCheckinButton extends StatefulWidget {
  final bool isChecked;
  final VoidCallback? onTap;

  const ClayCheckinButton({
    super.key,
    required this.isChecked,
    this.onTap,
  });

  @override
  State<ClayCheckinButton> createState() => _ClayCheckinButtonState();
}

class _ClayCheckinButtonState extends State<ClayCheckinButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // 三段式缩放：1.0 → 0.92（按压）→ 1.06（弹起超调）→ 1.0（回弹归位）
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.92),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.92, end: 1.06),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0),
        weight: 60,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _controller.forward(from: 0.0);
    widget.onTap?.call();
  }

  Color get _bgColor =>
      widget.isChecked ? const Color(0xFF59C992) : const Color(0xFFF87670);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      // padding 10px 外扩：视觉 72px 直径 + 10px × 2 = 92px 热区
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _bgColor,
              // 径向渐变模拟 3D 球体高光：左上亮 → 中间主色 → 右下暗
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                radius: 0.8,
                colors: [
                  Colors.white.withValues(alpha: 0.35),
                  _bgColor,
                  _bgColor.withValues(alpha: 0.82),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              // 微弱白色高光线框（浮雕边界）
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
              // 多层阴影叠加：顶部高光 + 底部深沉 + 内凹暗角
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(-2, -2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: widget.isChecked
                ? const Icon(Icons.check, color: Colors.white, size: 36)
                : null,
          ),
        ),
      ),
    );
  }
}

/// 爸妈宝首页「今日用药」服药打卡卡片
/// ─────────────────────────────
/// 3D 黏土风格 · 从左到右结构：
///   [○ 圆形打卡按钮]  [药品名称（加粗大字）]  [> 箭头]
///                       [单次剂量 · 时点（小字灰）]
///
/// 本组件为 StatelessWidget，由父组件通过 isChecked 控制打卡状态，
/// 以此实现跨天重置（todayDone == false 时父组件传入 isChecked = false）。
class MedicineCheckinCard extends StatelessWidget {
  /// 药品 ID
  final int medicationId;

  /// 药品名称
  final String medicationName;

  /// 剂量与时段信息，如 "1 粒 · 08:00"
  final String dosageInfo;

  /// 今日该时段是否已打卡
  final bool isChecked;

  /// 打卡/撤销回调
  final VoidCallback? onCheckinTap;

  /// 跳转药品详情回调
  final VoidCallback? onDetailTap;

  const MedicineCheckinCard({
    super.key,
    required this.medicationId,
    required this.medicationName,
    required this.dosageInfo,
    required this.isChecked,
    this.onCheckinTap,
    this.onDetailTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDetailTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          // 柔和弥散阴影 + 上部微弱高光（黏土悬浮感）
          boxShadow: [
            ...AppTheme.shadowCard,
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── 左侧：3D 黏土圆形打卡按钮 ──
            ClayCheckinButton(
              isChecked: isChecked,
              onTap: onCheckinTap,
            ),
            const SizedBox(width: 12),
            // ── 中间：药品信息（Expanded 撑满） ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicationName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dosageInfo,
                    style: const TextStyle(
                      fontSize: 22,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // ── 右侧：箭头导航 ──
            Icon(
              Icons.chevron_right,
              size: 32,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
