import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
    this.size = 78,
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
    final uncheckedLight = AppTheme.checkinUncheckedLight;
    final checkedColor = AppTheme.checkinChecked;
    final checkedDark = AppTheme.checkinCheckedDark;
    final checkedLight = AppTheme.checkinCheckedLight;
    final ringWidth = widget.size * 0.28;  // 圆环壁厚28%（效果图比例）
    final innerSize = widget.size - ringWidth * 2;

    // 已打卡：线性渐变实心圆 + 对勾（效果图风格）
    // 半哑光绒面质感，顶部高光边，底部接触阴影
    final checkedWidget = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            checkedLight,
            checkedColor,
            checkedDark,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          // 顶部高光边（圆弧高光）
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
          // 主下沉阴影（弥散投影）
          BoxShadow(
            color: checkedDark.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          // 接触阴影（极窄闭塞暗影）
          BoxShadow(
            color: checkedDark.withValues(alpha: 0.20),
            blurRadius: 2,
            offset: const Offset(0, 1),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 对勾阴影（立体分离感）
          Transform.translate(
            offset: const Offset(1.5, 2.5),
            child: CustomPaint(
              size: Size(widget.size * 0.42, widget.size * 0.42),
              painter: CheckmarkPainter(
                color: checkedDark.withValues(alpha: 0.45),
                strokeWidth: widget.size * 0.10,
                rounded: true,
              ),
            ),
          ),
          // 白色对勾主体（粗圆头3D）
          CustomPaint(
            size: Size(widget.size * 0.42, widget.size * 0.42),
            painter: CheckmarkPainter(
              color: Colors.white,
              strokeWidth: widget.size * 0.10,
              rounded: true,
            ),
          ),
        ],
      ),
    );

    // 未打卡：空心暖橙圆环（效果图黏土甜甜圈）
    // 内孔占44%，壁厚28%，半哑光质感，顶边高光+底部接触阴影
    final uncheckedWidget = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外层暖橙圆环（线性渐变顶亮底暗）
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  uncheckedLight,
                  uncheckedColor,
                  uncheckedDark,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 1.5,
              ),
              boxShadow: [
                // 顶部高光边
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
                // 主弥散阴影
                BoxShadow(
                  color: uncheckedDark.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                // 接触阴影
                BoxShadow(
                  color: uncheckedDark.withValues(alpha: 0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                  spreadRadius: -1,
                ),
              ],
            ),
          ),
          // 内层挖空圆（露出卡片底色）
          Container(
            width: widget.size - ringWidth * 2,
            height: widget.size - ringWidth * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFFFFF), // 卡片纯白色
              boxShadow: [
                // 内孔边缘暗影（凹陷感）
                BoxShadow(
                  color: uncheckedDark.withValues(alpha: 0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
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
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              children: [
                // 底层：大范围弥散阴影（真正3D立体感）
                // 单独渲染，不受按钮容器裁剪
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isChecked ? checkedDark : uncheckedDark).withValues(alpha: 0.25),
                          blurRadius: widget.size * 0.5,
                          offset: Offset(0, widget.size * 0.15),
                        ),
                      ],
                    ),
                  ),
                ),
                // 上层：按钮本体
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: widget.isChecked
                        ? SizedBox(key: const ValueKey('checked'), width: widget.size, height: widget.size, child: checkedWidget)
                        : SizedBox(key: const ValueKey('unchecked'), width: widget.size, height: widget.size, child: uncheckedWidget),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _buildStrongShadows(Color darkColor) {
    return [
      // 左上高光边（立体关键）
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.75),
        blurRadius: 4,
        offset: const Offset(-2, -2),
      ),
      // 主下沉阴影（悬浮）— 加大更有立体感
      BoxShadow(
        color: darkColor.withValues(alpha: 0.50),
        blurRadius: 18,
        offset: const Offset(4, 8),
      ),
      // 底部深阴影（厚度）
      BoxShadow(
        color: darkColor.withValues(alpha: 0.35),
        blurRadius: 8,
        offset: const Offset(0, 5),
      ),
      // 弥散光晕（饱满感）
      BoxShadow(
        color: darkColor.withValues(alpha: 0.15),
        blurRadius: 20,
        offset: const Offset(0, 0),
        spreadRadius: 2,
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
  final int? inventoryDays;       // 剩余可用天数
  final String? inventoryLevel;   // sufficient / warning / danger

  const MedicineCheckinCard({
    super.key,
    required this.medicationId,
    required this.medicationName,
    required this.doseInfo,
    required this.initialChecked,
    this.onCheckinChanged,
    this.onDetailTap,
    this.inventoryDays,
    this.inventoryLevel,
  });

  @override
  State<MedicineCheckinCard> createState() => _MedicineCheckinCardState();
}

class _MedicineCheckinCardState extends State<MedicineCheckinCard> {
  late bool _isChecked = widget.initialChecked;

  void _handleCheckinTap() {
    final newState = !_isChecked;
    setState(() {
      _isChecked = newState;
    });
    widget.onCheckinChanged?.call(_isChecked);
    // 打卡成功后弹"有无不适"反馈
    if (newState) {
      _showCheckinFeedback();
    }
  }

  /// 打卡后反馈：有没有不舒服？（异常可咨询医生）
  void _showCheckinFeedback() {
    final name = widget.medicationName;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✅ 已打卡！',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('吃了「$name」后有没有不舒服？',
                  style: const TextStyle(fontSize: 17, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _feedbackBtn(ctx, '👍 没有', Icons.sentiment_satisfied, AppTheme.secondaryColor, null),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _feedbackBtn(ctx, '😐 有点不适', Icons.sentiment_neutral, const Color(0xFFFF9800), '有点不适'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _feedbackBtn(ctx, '😣 很不舒服', Icons.sentiment_very_dissatisfied, AppTheme.warningColor, '很不舒服'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedbackBtn(BuildContext ctx, String label, IconData icon, Color color, String? level) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        if (level != null) {
          // 有不适 → 提示可咨询医生
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('已记录（$level）。如有持续不适，可在首页「我的医生」咨询医生'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  /// 显示购买渠道弹窗（京东/药店地图/提醒子女）
  void _showBuyChannels(BuildContext context) {
    final name = widget.medicationName;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_cart, color: AppTheme.primaryColor, size: 28),
                  const SizedBox(width: 10),
                  Text('购买 $name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              _channelItem(
                ctx,
                icon: Icons.shopping_bag,
                color: const Color(0xFFE53935),
                title: '京东大药房搜索',
                subtitle: '一键搜索该药品',
                onTap: () => _searchJD(ctx, name),
              ),
              const SizedBox(height: 12),
              _channelItem(
                ctx,
                icon: Icons.local_pharmacy,
                color: const Color(0xFF76D160),
                title: '附近药店',
                subtitle: '地图导航到附近药店',
                onTap: () => _searchPharmacy(ctx),
              ),
              const SizedBox(height: 12),
              _channelItem(
                ctx,
                icon: Icons.notifications_active,
                color: AppTheme.primaryColor,
                title: '提醒子女',
                subtitle: '发送短信通知家属买药',
                onTap: () => _remindFamily(ctx, name),
              ),
              const SizedBox(height: 12),
              _channelItem(
                ctx,
                icon: Icons.delivery_dining,
                color: const Color(0xFFFFC107),
                title: '美团外卖买药',
                subtitle: '美团送药上门，30分钟达',
                onTap: () => _searchMeituan(ctx, name),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _channelItem(BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  /// 京东大药房搜索
  Future<void> _searchJD(BuildContext ctx, String medName) async {
    Navigator.pop(ctx);
    final query = Uri.encodeComponent('$medName 药');
    final url = 'https://search.jd.com/Search?keyword=$query&enc=utf-8';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  /// 美团外卖买药搜索
  Future<void> _searchMeituan(BuildContext ctx, String medName) async {
    if (ctx.mounted) Navigator.pop(ctx);
    try {
      final query = Uri.encodeComponent(medName);
      final url = 'https://waimai.meituan.com/search?keyword=$query';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// 附近药店地图导航
  Future<void> _searchPharmacy(BuildContext ctx) async {
    Navigator.pop(ctx);
    final url = 'geo:0,0?q=药店';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      // 备用：用高德/百度地图网页版
      final webUrl = 'https://uri.amap.com/navigation?to=药店&mode=bus&coordinate=';
      if (await canLaunchUrl(Uri.parse(webUrl))) {
        await launchUrl(Uri.parse(webUrl));
      }
    }
  }

  /// 提醒子女
  Future<void> _remindFamily(BuildContext ctx, String medName) async {
    Navigator.pop(ctx);
    // 用系统分享发送提醒消息
    final text = '【爸妈宝提醒】$medName快用完了，请及时购买！';
    final uri = Uri(
      scheme: 'sms',
      path: '',
      queryParameters: {'body': text},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // 备用：复制到剪贴板
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提醒内容已复制到剪贴板'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDetailTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF), // 纯白（效果图）
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
                      fontSize: 26,
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
                      fontSize: 18,
                      color: Color(0xFF555555),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 库存预警
                  if (widget.inventoryDays != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          widget.inventoryLevel == 'danger'
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2_outlined,
                          size: 14,
                          color: widget.inventoryLevel == 'danger'
                              ? const Color(0xFFE53935)
                              : widget.inventoryLevel == 'warning'
                                  ? const Color(0xFFFF9F40)
                                  : const Color(0xFF76D160),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.inventoryDays! <= 0
                              ? '已用完！'
                              : '剩余约${widget.inventoryDays}天',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: widget.inventoryLevel == 'danger'
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: widget.inventoryLevel == 'danger'
                                ? const Color(0xFFE53935)
                                : widget.inventoryLevel == 'warning'
                                    ? const Color(0xFFFF9F40)
                                    : const Color(0xFF76D160),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // 右侧操作区
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 库存不足时显示购买按钮
                if (widget.inventoryLevel == 'danger' || widget.inventoryLevel == 'warning') ...[
                  GestureDetector(
                    onTap: () => _showBuyChannels(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.inventoryLevel == 'danger'
                            ? const Color(0xFFE53935).withValues(alpha: 0.12)
                            : const Color(0xFFFF9F40).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 16,
                            color: widget.inventoryLevel == 'danger'
                                ? const Color(0xFFE53935)
                                : const Color(0xFFFF9F40),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '购买',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.inventoryLevel == 'danger'
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFFFF9F40),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
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

/// 自定义3D黏土风格对勾绘制器
/// 粗线条、圆头端点、立体饱满感
class CheckmarkPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool rounded;

  CheckmarkPainter({
    required this.color,
    required this.strokeWidth,
    this.rounded = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final margin = strokeWidth * 0.6;

    // 对勾路径：左下短臂 → 中间转折 → 右上长臂
    path.moveTo(margin, h * 0.55);
    path.lineTo(w * 0.38, h * 0.78);
    path.lineTo(w - margin, margin);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CheckmarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
