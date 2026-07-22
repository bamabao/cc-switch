import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

/// 圆形状态指示器 — 设计稿立体风格
/// 未服药：空心橙红圆环（甜甜圈）+ 立体阴影
/// 已服药：薄荷绿实心圆 + 白色对勾 + 立体阴影
class CheckinIndicator extends StatefulWidget {
  final bool isChecked;
  final VoidCallback? onTap;
  final double size;
  const CheckinIndicator({
    super.key,
    required this.isChecked,
    this.onTap,
    this.size = 52,
  });
  @override
  State<CheckinIndicator> createState() => _CheckinIndicatorState();
}

class _CheckinIndicatorState extends State<CheckinIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.06), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _controller.forward(from: 0.0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final uncheckedColor = AppTheme.checkinUnchecked;
    final uncheckedDark = AppTheme.checkinUncheckedDark;
    final checkedColor = AppTheme.checkinChecked;
    final checkedDark = AppTheme.checkinCheckedDark;
    final ringWidth = widget.size * 0.26;  // 圆环加粗

    // 已打卡：渐变实心圆 + 对勾（对勾带分离立体阴影）
    final checkedWidget = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.45, -0.45),
          radius: 0.95,
          colors: [
            checkedColor.withValues(alpha: 1.0),
            checkedColor,
            checkedDark,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 3,
        ),
        boxShadow: _buildStrongShadows(checkedDark),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 对勾的立体阴影层（分离感）
          Transform.translate(
            offset: const Offset(1.5, 2.5),
            child: Icon(
              Icons.check,
              color: checkedDark.withValues(alpha: 0.45),
              size: 32,
              weight: 800,
            ),
          ),
          // 白色对勾主体
          const Icon(
            Icons.check,
            color: Colors.white,
            size: 32,
            weight: 800,
          ),
        ],
      ),
    );

    // 未打卡：空心橙红圆环（黏土甜甜圈立体感 + 内阴影）
    final uncheckedWidget = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外层：橙色阴影（营造悬浮感）
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.4),
                radius: 0.95,
                colors: [
                  uncheckedColor.withValues(alpha: 1.0),
                  uncheckedColor,
                  uncheckedDark,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: _buildStrongShadows(uncheckedDark),
            ),
          ),
          // 内层：白色小圆（挖空形成圆环）+ 内阴影营造凹面感
          Container(
            width: widget.size - ringWidth * 2,
            height: widget.size - ringWidth * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardColor,
              boxShadow: [
                // 内阴影（凹陷感）— 用外阴影反向模拟
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 2,
                  offset: const Offset(-1, -1),
                ),
                BoxShadow(
                  color: uncheckedDark.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
          ),
          // 圆环顶部高光弧（立体关键）
          Positioned(
            top: 2,
            child: Container(
              width: widget.size * 0.5,
              height: widget.size * 0.12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: widget.isChecked
                ? SizedBox(key: const ValueKey('checked'), width: widget.size, height: widget.size, child: checkedWidget)
                : SizedBox(key: const ValueKey('unchecked'), width: widget.size, height: widget.size, child: uncheckedWidget),
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _buildStrongShadows(Color darkColor) {
    return [
      // 左上高光边（立体关键）
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.65),
        blurRadius: 2,
        offset: const Offset(-1, -1),
      ),
      // 主下沉阴影（悬浮）— 加大更有立体感
      BoxShadow(
        color: darkColor.withValues(alpha: 0.45),
        blurRadius: 14,
        offset: const Offset(3, 7),
      ),
      // 底部深阴影（厚度）
      BoxShadow(
        color: darkColor.withValues(alpha: 0.30),
        blurRadius: 6,
        offset: const Offset(0, 4),
      ),
      // 右下重阴影（黏土挤压感）
      BoxShadow(
        color: darkColor.withValues(alpha: 0.18),
        blurRadius: 3,
        offset: const Offset(2, 3),
      ),
    ];
  }
}

/// 爸妈宝药品卡片 — 白色悬浮卡片（设计稿标准）
/// 内部管理自己的勾选状态，避免整体重建导致闪烁
class MedicineCheckinCard extends StatefulWidget {
  final int medicationId;
  final String medicationName;
  final String doseInfo;
  final bool initialChecked;
  final ValueChanged<bool>? onCheckinChanged;
  final VoidCallback? onDetailTap;

  const MedicineCheckinCard({
    super.key,
    required this.medicationId,
    required this.medicationName,
    required this.doseInfo,
    required this.initialChecked,
    this.onCheckinChanged,
    this.onDetailTap,
  });

  @override
  State<MedicineCheckinCard> createState() => _MedicineCheckinCardState();
}

class _MedicineCheckinCardState extends State<MedicineCheckinCard> {
  late bool _isChecked = widget.initialChecked;

  void _handleCheckinTap() {
    setState(() {
      _isChecked = !_isChecked;
    });
    widget.onCheckinChanged?.call(_isChecked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDetailTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF2), // 淡奶白色
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: _buildCardShadows(),
        ),
        child: Row(
          children: [
            // 左侧状态指示器
            CheckinIndicator(
              isChecked: _isChecked,
              onTap: _handleCheckinTap,
              size: 40,
            ),
            const SizedBox(width: 10),
            // 药品文字信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.medicationName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.doseInfo,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 右侧灰色箭头
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Icon(
                Icons.chevron_right,
                size: 22,
                color: AppTheme.textLightGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 卡片立体浮雕阴影
  List<BoxShadow> _buildCardShadows() {
    return [
      // 顶部细高光（凸起感）
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.9),
        blurRadius: 1,
        offset: const Offset(0, -1),
      ),
      // 左上高光边
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.6),
        blurRadius: 4,
        offset: const Offset(-1, -1),
      ),
      // 主下沉阴影（悬浮感）
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
      // 底部深阴影（厚度）
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.10),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
      // 右下重阴影（黏土挤压）
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 4,
        offset: const Offset(2, 3),
      ),
    ];
  }
}
