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
  final bool disabled; // 标题行按钮禁用点击

  const ClayCheckinButton({
    super.key,
    required this.isChecked,
    this.onTap,
    this.disabled = false,
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
    if (widget.disabled) return;
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
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

/// 爸妈宝首页「今日用药」多时段打卡卡片
/// ────────────────────────────────────
/// 一种药品一张卡片，卡片下方竖向罗列该药所有时段
/// 每个时段配独立ClayCheckinButton，红/绿状态各自独立
///
/// 顶部标题行结构：
///   [ClayCheckinButton(disabled)]  [药名 · 剂量(加粗)]  [>箭头]
///                                  [剂量 · 首个时段(小字灰)]
///
/// 下方时段行结构（N行，N=该药每日服用次数）：
///   [ClayCheckinButton(active)]  [时段时间·剂量(加粗)]
///
/// 标题行按钮仅作整体状态表示（全部打完→绿，否则→红），不可点击
/// 时段行按钮每个独立可点击，打卡/撤销双向切换
class MedicineCheckinCard extends StatefulWidget {
  final int medicationId;
  final String medicationName;
  final dynamic dosagePerTake;
  final String unit;
  final List<dynamic> schedules; // 后端返回的 schedules 数组
  final int checkedSlots;
  final int totalSlots;
  final VoidCallback? onDetailTap;
  final Function(int scheduleIndex)? onCheckinTap;

  const MedicineCheckinCard({
    super.key,
    required this.medicationId,
    required this.medicationName,
    this.dosagePerTake,
    this.unit = '',
    required this.schedules,
    required this.checkedSlots,
    required this.totalSlots,
    this.onDetailTap,
    this.onCheckinTap,
  });

  @override
  State<MedicineCheckinCard> createState() => _MedicineCheckinCardState();
}

class _MedicineCheckinCardState extends State<MedicineCheckinCard> {
  /// 是否全部时段已打卡
  bool get _allChecked => widget.checkedSlots >= widget.totalSlots && widget.totalSlots > 0;

  /// 药名后的剂量+时段描述 如 "1粒 · 08:00 / 20:00"
  String get _headerDoseInfo {
    final sb = StringBuffer();
    if (widget.dosagePerTake != null && widget.unit.isNotEmpty) {
      sb.write('${widget.dosagePerTake} ${widget.unit}');
    }
    if (widget.schedules.isNotEmpty) {
      final times = widget.schedules.map((s) => s['time'] as String? ?? '').where((t) => t.isNotEmpty).join(' / ');
      if (times.isNotEmpty) {
        if (sb.isNotEmpty) sb.write(' · ');
        sb.write(times);
      }
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDetailTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: [
            ...AppTheme.shadowCard,
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 标题行 ──
            _buildHeaderRow(),
            // ── 各时段行 ──
            if (widget.schedules.length >= 1) ...[
              const SizedBox(height: 8),
              _buildDivider(),
              const SizedBox(height: 8),
              ...widget.schedules.asMap().entries.map(
                (entry) => Padding(
                  padding: entry.key > 0
                      ? const EdgeInsets.only(top: 8)
                      : EdgeInsets.zero,
                  child: _buildScheduleRow(entry.key),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        // ── 标题行按钮（禁用，仅状态标识） ──
        ClayCheckinButton(
          isChecked: _allChecked,
          disabled: true,
        ),
        const SizedBox(width: 12),
        // ── 药品信息 ──
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.medicationName,
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
                _headerDoseInfo,
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
        // ── 箭头导航 ──
        const Icon(
          Icons.chevron_right,
          size: 32,
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 92), // 对齐按钮右侧
      height: 1,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE0E0E0).withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleRow(int index) {
    final schedule = widget.schedules[index];
    final time = schedule['time'] as String? ?? '';
    final checked = schedule['checked'] as bool? ?? false;
    final dose = widget.dosagePerTake != null
        ? '${widget.dosagePerTake} ${widget.unit}'
        : '';

    return Row(
      children: [
        // ── 独立可点击的打卡按钮 ──
        ClayCheckinButton(
          isChecked: checked,
          onTap: () => widget.onCheckinTap?.call(index),
          disabled: false,
        ),
        const SizedBox(width: 12),
        // ── 时段时间 + 剂量 ──
        Expanded(
          child: Row(
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (dose.isNotEmpty) ...[
                const SizedBox(width: 16),
                Text(
                  dose,
                  style: const TextStyle(
                    fontSize: 24,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              if (checked) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.check_circle,
                  size: 28,
                  color: const Color(0xFF59C992),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
