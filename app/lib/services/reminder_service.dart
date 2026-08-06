import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../services/notification_service.dart';
import '../models/medication_dose.dart';

/// 爸妈宝 — 提醒调度/存储服务
/// 封装：后端 API 存储 + 本地精确闹钟通知 + 语音播报
class ReminderService {
  final ApiService _api = ApiService();

  /// 保存提醒到后端
  Future<bool> saveReminder({
    required int medicationId,
    required MedicationDose dose,
  }) async {
    try {
      final body = dose.toJson(medicationId);
      await _api.post(ApiConfig.reminders, body: body);
      return true;
    } catch (e) {
      debugPrint('保存提醒失败: $e');
      return false;
    }
  }

  /// 触发服药提醒（实际场景：由后台调度或闹铃唤起时调用）
  static Future<void> triggerReminder({
    required String medicationName,
    required MedicationDose dose,
    TimeOfDay? slotTime,
  }) async {
    switch (dose.reminderType) {
      case ReminderType.systemAlarm:
        // 系统闹铃 — 由 NotificationService 的精确闹钟调度
        debugPrint('[提醒] 系统闹铃 — $medicationName ${slotTime != null ? '${slotTime.hour}:${slotTime.minute}' : ''}');
        break;

      case ReminderType.backgroundMusic:
        debugPrint('[提醒] 背景音乐 — $medicationName path: ${dose.musicPath}');
        break;

      case ReminderType.voiceBroadcast:
        await _broadcastVoice(medicationName, dose.voiceTitle);
        break;
    }
  }

  /// 语音播报逻辑
  static Future<void> _broadcastVoice(String medicationName, String? voiceTitle) async {
    final title = voiceTitle ?? '宝宝';
    final text = '$title，该吃药了，请按时服用$medicationName';
    try {
      await VoiceService().speak(text);
    } catch (e) {
      debugPrint('语音播报失败: $e');
    }
  }

  /// 多时段批量调度提醒（App被杀也能响铃）
  Future<void> scheduleAllSlots({
    required int medicationId,
    required String medicationName,
    required MedicationDose dose,
  }) async {
    final notif = NotificationService.instance;

    // 先取消旧提醒，防止重复
    await notif.cancelForMedication(medicationId);

    // 每个时段注册一个每日精确闹钟
    for (var i = 0; i < dose.timeSlots.length; i++) {
      final slot = dose.timeSlots[i];
      final dosageText = dose.dosageAmount != null && dose.dosageUnit != null
          ? '${dose.dosageAmount}${dose.dosageUnit}'
          : '';
      await notif.scheduleDailyReminder(
        medicationId: medicationId,
        medicationName: medicationName,
        dosageText: dosageText,
        time: slot,
      );
      debugPrint('[提醒] 调度时段$i: ${slot.hour}:${slot.minute} $medicationName');
    }

    // 同时保存到后端
    for (final slot in dose.timeSlots) {
      final slotDose = dose.copyWith(timeSlots: [slot]);
      await saveReminder(medicationId: medicationId, dose: slotDose);
    }
  }

  /// 朗读页面文字（适老「一键朗读」功能）
  static Future<void> readPageText(String text) async {
    await VoiceService().speak(text);
  }
}
