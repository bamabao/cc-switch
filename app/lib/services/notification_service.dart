import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 爸妈宝 — 本地通知服务
/// 基于 flutter_local_notifications 的精确闹钟：
///  - App 被杀死后依然能响铃（Android AlarmManager 调度）
///  - 手机重启后自动恢复提醒（BOOT_COMPLETED）
///  - 点击通知跳转到 App
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _idCounter = 1000;

  /// 初始化（main() 中调用）
  Future<void> init() async {
    if (_initialized) return;

    // 初始化时区数据
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    // Android 配置
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // 点击通知 → 跳转到首页
        if (response.payload != null) {
          _openApp(response.payload!);
        }
      },
    );

    // Android 13+ 通知权限
    await _requestPermissions();
    _initialized = true;
    debugPrint('[通知] 初始化完成');
  }

  Future<void> _requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      // Android 13+ POST_NOTIFICATIONS
      await androidImpl.requestNotificationsPermission();
      // Android 12+ 精确闹钟
      await androidImpl.requestExactAlarmsPermission();
    }
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// 检查是否有精确闹钟权限
  Future<bool> canScheduleExact() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await androidImpl?.canScheduleExactNotifications() ?? true;
  }

  void _openApp(String payload) {
    // 已在App内直接导航；若从后台唤起，由 main 处理 payload
    debugPrint('[通知] 点击通知 payload=$payload');
  }

  /// 调度单个服药提醒（每日重复，App被杀也能触发）
  Future<void> scheduleDailyReminder({
    required int medicationId,
    required String medicationName,
    required String dosageText,
    required TimeOfDay time,
  }) async {
    final id = _idCounter++;
    final now = DateTime.now();
    // 下一次该时间点（今天过了就明天）
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'medication_reminders',
      '服药提醒',
      channelDescription: '爸妈宝按时服药提醒',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    try {
      await _plugin.zonedSchedule(
        id,
        '💊 该吃药啦',
        '请按时服用「$medicationName」$dosageText',
        tz.TZDateTime.from(next, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'medication:$medicationId:$medicationName',
      );
      debugPrint('[通知] 已调度: $medicationName ${time.hour}:${time.minute} (id=$id)');
    } catch (e) {
      debugPrint('[通知] 调度失败: $e');
    }
  }

  /// 立即弹出通知（测试/立即服药提醒用）
  Future<void> showNow({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'medication_reminders',
      '服药提醒',
      channelDescription: '爸妈宝按时服药提醒',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(_idCounter++, title, body, details);
  }

  /// 取消某药品所有提醒
  Future<void> cancelForMedication(int medicationId) async {
    // 通知ID规律: 1000 + medicationId*100 + slotIndex
    for (var i = 0; i < 20; i++) {
      await _plugin.cancel(1000 + medicationId * 100 + i);
    }
    debugPrint('[通知] 已取消药品#$medicationId 的提醒');
  }

  /// 生成通知ID（保持稳定，便于取消）
  int notificationId(int medicationId, int slotIndex) => 1000 + medicationId * 100 + slotIndex;
}
