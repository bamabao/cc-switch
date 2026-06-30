import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

/// 积分打卡弹窗 — 服药后打卡成功
/// P0-5：积分打卡（弹窗方案，非独立页面）
/// v2黏土软萌风格
class CheckinPopup extends StatefulWidget {
  final int consecutiveDays;
  final int pointsEarned;
  final int totalPoints;
  final int longestStreak;

  const CheckinPopup({
    super.key,
    this.consecutiveDays = 1,
    this.pointsEarned = 3,
    this.totalPoints = 0,
    this.longestStreak = 1,
  });

  /// 便捷调用 — 自动从后端拉积分数据
  static Future<void> show(BuildContext context, {int pointsEarned = 10}) async {
    final api = ApiService();
    int consecutiveDays = 1;
    int totalPoints = 0;
    int longestStreak = 1;
    try {
      final profile = await api.get('${ApiConfig.points}/profile?elder_id=1');
      consecutiveDays = profile['current_streak'] as int? ?? 1;
      totalPoints = profile['total_points'] as int? ?? 0;
      longestStreak = profile['longest_streak'] as int? ?? 1;
    } catch (_) {}
    if (!context.mounted) return;
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: false,
      builder: (_) => CheckinPopup(
        consecutiveDays: consecutiveDays,
        pointsEarned: pointsEarned,
        totalPoints: totalPoints,
        longestStreak: longestStreak,
      ),
    );
  }

  @override
  State<CheckinPopup> createState() => _CheckinPopupState();
}

class _CheckinPopupState extends State<CheckinPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _motivationText {
    if (widget.consecutiveDays >= 30) return '一个月全勤！太厉害了，家人都为您骄傲 ❤️';
    if (widget.consecutiveDays >= 7) return '整整一周没落下！您是模范生 🏆';
    if (widget.consecutiveDays >= 3) return '坚持三天了，身体会越来越好 💪';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingXl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎉 标题
              const Text(
                '🎉 打卡成功！',
                style: TextStyle(
                  fontSize: AppTheme.displayMedium,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // 超大积分数字
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF9F40), Color(0xFF76D160)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  '+${widget.pointsEarned}',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Text(
                '积分已到账',
                style: TextStyle(
                  fontSize: AppTheme.bodyLarge,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // 每日主文案
              const Text(
                '今天又按时吃药了，真棒！',
                style: TextStyle(
                  fontSize: AppTheme.titleMedium,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // 连续打卡日
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '🔥',
                    style: TextStyle(fontSize: AppTheme.titleLarge),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '连续打卡 ${widget.consecutiveDays} 天',
                    style: const TextStyle(
                      fontSize: AppTheme.bodyLarge,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // 激励文案
              if (_motivationText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _motivationText,
                  style: const TextStyle(
                    fontSize: AppTheme.bodyLarge,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 32),

              // 关闭按钮
              SizedBox(
                width: double.infinity,
                height: AppTheme.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textOnDark,
                    elevation: 4,
                    shadowColor:
                        const Color(0xFF3A4437).withValues(alpha: 0.15),
                    textStyle: const TextStyle(
                      fontSize: AppTheme.titleMedium,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: AppTheme.textPrimary,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusButton),
                    ),
                  ),
                  child: const Text('好的'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
