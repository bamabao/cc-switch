import 'package:flutter/material.dart';
import '../../config/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于爸妈宝')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.elderly, size: 64, color: AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: Text('爸妈宝', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          const Center(child: Text('v2.1', style: TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textSecondary))),
          const SizedBox(height: 8),
          const Center(child: Text('让爸妈用药更安心', style: TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textSecondary))),
          const SizedBox(height: 48),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(Icons.code, color: AppTheme.primaryColor), title: const Text('版本'), trailing: const Text('v2.1')),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.description, color: AppTheme.primaryColor), title: const Text('用户协议'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.privacy_tip, color: AppTheme.primaryColor), title: const Text('隐私政策'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.email, color: AppTheme.primaryColor), title: const Text('联系我们'), subtitle: const Text('7489799@qq.com')),
            ]),
          ),
        ],
      ),
    );
  }
}
