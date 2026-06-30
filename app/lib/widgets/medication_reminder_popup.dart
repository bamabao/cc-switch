import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 用药提醒全屏弹窗 — P0最高优先级
/// 展示药名/用量/注意事项 + "已服药"二次确认
class MedicationReminderPopup extends StatefulWidget {
  final String medicationName;
  final String dosage;
  final String note;
  final bool isReminder;

  const MedicationReminderPopup({
    super.key,
    required this.medicationName,
    this.dosage = '2粒',
    this.note = '饭后服用，忌酒',
    this.isReminder = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String medicationName,
    String dosage = '2粒',
    String note = '饭后服用，忌酒',
    bool isReminder = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      barrierDismissible: false,
      builder: (_) => MedicationReminderPopup(
        medicationName: medicationName,
        dosage: dosage,
        note: note,
        isReminder: isReminder,
      ),
    );
  }

  @override
  State<MedicationReminderPopup> createState() =>
      _MedicationReminderPopupState();
}

class _MedicationReminderPopupState extends State<MedicationReminderPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  String? _feedbackMessage;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTaken() {
    setState(() => _feedbackMessage = '✅ 已记录');
    // 二次确认 — 震动+语音反馈
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  void _handleLater() {
    setState(() => _feedbackMessage = '⏰ 好的，5分钟后再提醒您');
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  void _handleSkip() {
    setState(() => _feedbackMessage = '❌ 已记录，我们会通知您的家人');
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      insetPadding: const EdgeInsets.all(0),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: _feedbackMessage != null
                ? _buildFeedback()
                : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        // ⏰ 大标题
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '⏰',
              style: TextStyle(
                  fontSize: AppTheme.displayMedium),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.isReminder ? '您可能忘记吃药了' : '吃药时间到啦',
          style: TextStyle(
            fontSize: AppTheme.headlineLarge,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 24),

        // 药品信息
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: Column(
            children: [
              Text(
                widget.medicationName,
                style: TextStyle(
                  fontSize: AppTheme.headlineMedium,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '用量：${widget.dosage}',
                style: TextStyle(
                  fontSize: AppTheme.titleMedium,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '注意：${widget.note}',
                style: TextStyle(
                  fontSize: AppTheme.bodyLarge,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 大声重读按钮
        TextButton.icon(
          onPressed: () {
            // TODO: TTS 语音播报
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('正在播报：该吃药了…'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          icon: Icon(Icons.volume_up, color: AppTheme.primaryColor, size: 28),
          label: Text(
            '大声重读',
            style: TextStyle(
              fontSize: AppTheme.bodyLarge,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 三个选项
        SizedBox(
          width: double.infinity,
          height: AppTheme.buttonHeight,
          child: ElevatedButton.icon(
            onPressed: _handleTaken,
            icon: const Icon(Icons.check_circle, size: 32),
            label: const Text('我吃好了'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              foregroundColor: AppTheme.textOnDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
              textStyle: TextStyle(
                fontSize: AppTheme.titleMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: AppTheme.buttonHeight * 0.8,
                child: OutlinedButton.icon(
                  onPressed: _handleLater,
                  icon: const Icon(Icons.timer_outlined, size: 24),
                  label: const Text('等一会再吃'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    ),
                    textStyle: TextStyle(
                      fontSize: AppTheme.bodyLarge,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: AppTheme.buttonHeight * 0.8,
                child: OutlinedButton.icon(
                  onPressed: _handleSkip,
                  icon: const Icon(Icons.close, size: 24),
                  label: const Text('今天不吃了'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppTheme.warningColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    ),
                    textStyle: TextStyle(
                      fontSize: AppTheme.bodyLarge,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: widget.isReminder ? 12 : 24),
        if (widget.isReminder)
          Text(
            '现在补上还来得及哦',
            style: TextStyle(
              fontSize: AppTheme.bodyMedium,
              color: AppTheme.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildFeedback() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _feedbackMessage!,
            style: TextStyle(
              fontSize: AppTheme.headlineLarge,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
