import 'package:flutter/material.dart';

/// 爸妈宝 — 药品剂量+提醒数据模型
enum ReminderType {
  systemAlarm,
  backgroundMusic,
  voiceBroadcast,
}

class MedicationDose {
  final String dosageAmount;
  final String dosageUnit;
  final int frequencyPerDay;
  final List<TimeOfDay> timeSlots;
  final ReminderType reminderType;
  final String? voiceTitle;
  final String? musicPath;

  const MedicationDose({
    this.dosageAmount = '',
    this.dosageUnit = '粒',
    this.frequencyPerDay = 1,
    this.timeSlots = const [],
    this.reminderType = ReminderType.systemAlarm,
    this.voiceTitle,
    this.musicPath,
  });

  MedicationDose copyWith({
    String? dosageAmount,
    String? dosageUnit,
    int? frequencyPerDay,
    List<TimeOfDay>? timeSlots,
    ReminderType? reminderType,
    String? voiceTitle,
    String? musicPath,
  }) {
    return MedicationDose(
      dosageAmount: dosageAmount ?? this.dosageAmount,
      dosageUnit: dosageUnit ?? this.dosageUnit,
      frequencyPerDay: frequencyPerDay ?? this.frequencyPerDay,
      timeSlots: timeSlots ?? this.timeSlots,
      reminderType: reminderType ?? this.reminderType,
      voiceTitle: voiceTitle ?? this.voiceTitle,
      musicPath: musicPath ?? this.musicPath,
    );
  }

  Map<String, dynamic> toJson(int medicationId) {
    return {
      'medication_id': medicationId,
      'dosage_amount': dosageAmount,
      'dosage_unit': dosageUnit,
      'frequency_per_day': frequencyPerDay,
      'time_slots': timeSlots
          .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
          .toList(),
      'reminder_type': reminderType.name,
      'voice_title': voiceTitle,
      'music_path': musicPath,
      'enabled': true,
    };
  }
}
