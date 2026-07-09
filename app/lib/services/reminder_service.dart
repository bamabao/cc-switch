import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../models/medication_dose.dart';

/// 爸妈宝 — 提醒调度/存储服务
/// 封装：后端 API 存储 + 本地通知调度 + 语音播报
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
        // 系统闹铃 — 依赖 flutter_local_notifications 或原生 AlarmManager
        // 此处 placeholder，实际由本地通知插件调度
        debugPrint('[提醒] 系统闹铃 — $medicationName ${slotTime != null ? '${slotTime.hour}:${slotTime.minute}' : ''}');
        break;

      case ReminderType.backgroundMusic:
        // 背景音乐 — 使用 AudioPlayer 播放音乐文件
        // 此处 placeholder，后续集成 audio_player 播放 dose.musicPath
        debugPrint('[提醒] 背景音乐 — $medicationName path: ${dose.musicPath}');
        break;

      case ReminderType.voiceBroadcast:
        // 讯飞语音播报
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

  /// 多时段批量调度提醒
  Future<void> scheduleAllSlots({
    required int medicationId,
    required String medicationName,
    required MedicationDose dose,
  }) async {
    // 每个时段独立保存到后端
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
