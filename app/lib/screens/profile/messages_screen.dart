import 'package:flutter/material.dart';
import '../../config/theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final List<Map<String, dynamic>> _messages = [
    {'title': '用药提醒', 'body': '该服用阿莫西林胶囊了（08:00）', 'time': '2026-07-02 08:00', 'type': 'reminder', 'read': false},

    {'title': '积分到账', 'body': '按时用药获得 +10 积分', 'time': '2026-07-01 08:00', 'type': 'points', 'read': true},
    {'title': '药品预警', 'body': '阿莫西林胶囊将于3天后过期', 'time': '2026-06-30 10:00', 'type': 'alert', 'read': true},
    {'title': '连续打卡', 'body': '恭喜！您已连续打卡7天，获得50积分奖励', 'time': '2026-06-28 08:05', 'type': 'points', 'read': true},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息通知')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        itemCount: _messages.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingSm),
        itemBuilder: (_, i) {
          final msg = _messages[i];
          IconData icon;
          Color color;
          switch (msg['type'] as String) {
            case 'reminder': icon = Icons.alarm; color = AppTheme.primaryColor; break;

            case 'points': icon = Icons.star; color = AppTheme.warningColor; break;
            case 'alert': icon = Icons.warning_amber; color = AppTheme.dangerColor; break;
            default: icon = Icons.notifications; color = AppTheme.textSecondary;
          }
          return Card(
            child: ListTile(
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              title: Row(
                children: [
                  Text(msg['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.bodyLarge)),
                  if (!(msg['read'] as bool))
                    Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(color: AppTheme.dangerColor, shape: BoxShape.circle)),
                ],
              ),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 4),
                Text(msg['body'] as String, style: const TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(msg['time'] as String, style: const TextStyle(fontSize: AppTheme.bodySmall, color: AppTheme.textSecondary)),
              ]),
              trailing: const Icon(Icons.chevron_right, size: 24),
            ),
          );
        },
      ),
    );
  }
}
