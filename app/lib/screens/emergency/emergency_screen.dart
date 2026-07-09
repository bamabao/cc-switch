import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

/// 紧急求助页 — 三连紧急救援链路
/// P1-6：一键打电话、返回首页、在线帮助
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _isCalling = false;
  int _countdown = 5;
  String _emergencyPhone = '120';
  // ignore: unused_field
  String _emergencyName = '紧急联系人';

  @override
  void initState() {
    super.initState();
    _loadPrimaryContact();
  }

  Future<void> _loadPrimaryContact() async {
    try {
      final result = await _api.get('${ApiConfig.emergencyContactPrimary}?token=${_api.token ?? ""}');
      if (result['phone'] != null && (result['phone'] as String).isNotEmpty) {
        _emergencyPhone = result['phone'] as String;
        // ignore: unused_field
        _emergencyName = result['name'] as String? ?? '紧急联系人';
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    _emergencyName;  // reference to suppress unused warning
    return Scaffold(
      backgroundColor: AppTheme.warningColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // 标题
              const Text(
                '⚠️ 需要帮助吗？',
                style: TextStyle(
                  fontSize: AppTheme.headlineLarge,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textOnDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '别着急，我们来帮您',
                style: TextStyle(
                  fontSize: AppTheme.bodyLarge,
                  color: AppTheme.textOnDark.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 48),

              // 三大按钮
              _buildEmergencyButton(
                icon: Icons.phone,
                label: '一键打电话',
                subtitle: '联系紧急联系人',
                color: const Color(0xFF2BA84A),
                onTap: _startEmergencyCall,
              ),
              const SizedBox(height: 16),
              _buildEmergencyButton(
                icon: Icons.home,
                label: '返回首页',
                subtitle: '回到主页面',
                color: const Color(0xFF1565C0),
                onTap: () => Navigator.pushReplacementNamed(context, '/home'),
              ),
              const SizedBox(height: 16),
              _buildEmergencyButton(
                icon: Icons.headset_mic,
                label: '在线帮助',
                subtitle: '联系客服人员',
                color: AppTheme.primaryColor,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('在线帮助'),
                      content: Text('如需帮助，请联系您的子女或拨打紧急联系人电话：$_emergencyPhone\n\n客服功能即将上线，敬请期待。'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('好的')),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(),

              // 取消按钮
              if (!_isCalling)
                SizedBox(
                  width: double.infinity,
                  height: AppTheme.buttonHeight,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      ),
                    ),
                    child: const Text(
                      '不需要帮助，返回',
                      style: TextStyle(
                        fontSize: AppTheme.titleMedium,
                        color: AppTheme.textOnDark,
                      ),
                    ),
                  ),
                ),

              if (_isCalling) _buildCallingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 120,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppTheme.textOnDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          elevation: 6,
          shadowColor: color.withValues(alpha: 0.4),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(icon, size: 48),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: AppTheme.headlineMedium, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textOnDark.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startEmergencyCall() {
    setState(() {
      _isCalling = true;
      _countdown = 5;
    });
    // 倒计时 — 5秒内可取消
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_countdown > 0) _countdown--;
      });
      return _countdown > 0 && mounted;
    }).then((_) {
      if (mounted) {
        _makePhoneCall('tel:$_emergencyPhone');
      }
    });
  }

  Future<void> _makePhoneCall(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('暂无法拨打电话，请手动拨打$_emergencyPhone')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('暂无法拨打电话，请手动拨打$_emergencyPhone')),
      );
    }
    if (mounted) setState(() => _isCalling = false);
  }

  Widget _buildCallingOverlay() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        children: [
          Text(
            '$_countdown',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Text('秒后将自动拨打电话', style: TextStyle(color: Colors.white70, fontSize: 20)),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ElevatedButton(
              onPressed: () => setState(() => _isCalling = false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.warningColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
              child: const Text('取消拨号', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
