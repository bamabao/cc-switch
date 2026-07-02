import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../auth/kid_binding_screen.dart';
import '../profile/settings_screen.dart';
import 'messages_screen.dart';
import 'health_record_screen.dart';
import 'emergency_contact_screen.dart';
import 'about_screen.dart';

/// 个人中心 — 对接后端真实API
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  UserProfile? _user;
  bool _loading = true;
  int _totalPoints = 0;
  int _streak = 0;
  List<Map<String, dynamic>> _family = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await _api.getMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _totalPoints = user.totalPoints;
        _family = user.familyMembers.map((m) => {
          'name': m['name'] ?? (m['nickname'] ?? ''),
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // 用户信息卡
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          AppTheme.primaryLight.withValues(alpha: 0.3),
                      child: Icon(Icons.person,
                          size: 40, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loading ? '加载中…' : (_user?.name ?? '用户'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        if (!_loading) ...[
                          Text(
                            '星星: $_totalPoints  | 已连续 $_streak 天',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          if (_family.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '家人: ${_family.map((f) => f['name']).join('、')}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            // 功能列表
            _buildMenuItem(context,
                icon: Icons.family_restroom, title: '家庭绑定',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const KidBindingScreen()))),
            _buildMenuItem(context,
                icon: Icons.notifications, title: '消息通知',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()))),
            _buildMenuItem(context,
                icon: Icons.assignment, title: '健康档案',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HealthRecordScreen()))),
            _buildMenuItem(context,
                icon: Icons.settings, title: '设置',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()))),
            _buildMenuItem(context,
                icon: Icons.phone_in_talk, title: '紧急联系人',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EmergencyContactManageScreen()))),
            _buildMenuItem(context,
                icon: Icons.info_outline, title: '关于',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()))),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context,
      {required IconData icon, required String title, VoidCallback? onTap}) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
        leading: Icon(icon, size: 32, color: AppTheme.primaryColor),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        trailing: const Icon(Icons.chevron_right, size: 32),
        onTap: onTap,
      ),
    );
  }
}
