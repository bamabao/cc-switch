/// 爸妈宝 免责声明组件
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 免责声明横幅 — 在药品详情/用药提醒等页面底部展示
class DisclaimerBanner extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;

  const DisclaimerBanner({super.key, this.compact = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFFFFF8E1);
    final borderColor = const Color(0xFFFFE082);
    final iconColor = const Color(0xFFF57C00);
    final textColor = const Color(0xFF795548);

    return GestureDetector(
      onTap: onTap ?? () => _showFullDisclaimer(context),
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: iconColor, size: compact ? 16 : 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                compact
                    ? '本提醒仅供参考，具体用药请遵医嘱'
                    : '【重要提醒】所有用药提醒、药品说明、AI问答仅供参考，不能替代专业医疗建议。请以医生处方和指导为准，如有不适立即就医。',
                style: TextStyle(
                  fontSize: compact ? 12 : 14,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ),
            if (compact) Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /// 弹出完整免责声明
  static void _showFullDisclaimer(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 24),
            SizedBox(width: 10),
            Text('免责声明', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          '爸妈宝提供的所有用药提醒、药品说明书、AI问答内容仅供参考，不能替代专业医疗建议。\n\n'
          '在使用本App的任何功能前，请务必：\n'
          '1️⃣ 咨询专业医生或药师\n'
          '2️⃣ 以医生的处方和指导为准\n'
          '3️⃣ 定期到医院复查\n'
          '4️⃣ 如有不适，立即就医\n\n'
          '本App不承担因使用提醒信息而产生的任何医疗责任。',
          style: TextStyle(fontSize: 16, height: 1.6, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }
}
