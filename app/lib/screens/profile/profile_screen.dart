import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../auth/kid_binding_screen.dart';
import '../profile/settings_screen.dart';

/// 个人中心
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
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
                    child: const Icon(Icons.person,
                        size: 40, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('用户',
                          style: Theme.of(context).textTheme.headlineMedium),
                      Text('积分: 1,280',
                          style: Theme.of(context).textTheme.bodyLarge),
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
              icon: Icons.notifications, title: '消息通知'),
          _buildMenuItem(context,
              icon: Icons.assignment, title: '健康档案'),
          _buildMenuItem(context,
              icon: Icons.settings, title: '设置',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          _buildMenuItem(context,
              icon: Icons.phone_in_talk, title: '紧急联系人'),
          _buildMenuItem(context,
              icon: Icons.info_outline, title: '关于'),
        ],
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
