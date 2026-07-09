/// 药品数据模型
class Medication {
  final int? id;
  final int elderId;
  final String name;          // 药品名
  final String? dosage;       // 剂量（如 "一粒""5ml"）
  final String? frequency;    // 频率（如 "一天两次""一日三次"）
  final String? notes;        // 备注
  final String status;        // 药品状态
  final DateTime createdAt;
  final DateTime updatedAt;

  Medication({
    this.id,
    required this.elderId,
    required this.name,
    this.dosage,
    this.frequency,
    this.notes,
    this.status = 'approved',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as int?,
      elderId: json['elder_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String?,
      frequency: json['frequency'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'approved',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'elder_id': elderId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'notes': notes,
      'status': status,
    };
  }
}

/// 用药提醒数据模型
class MedicationSchedule {
  final int? id;
  final int medicationId;
  final String timeOfDay;     // 如 "08:00"
  final String? dosageDesc;  // 如 "一粒"
  final bool isEnabled;

  MedicationSchedule({
    this.id,
    required this.medicationId,
    required this.timeOfDay,
    this.dosageDesc,
    this.isEnabled = true,
  });

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) {
    return MedicationSchedule(
      id: json['id'] as int?,
      medicationId: json['medication_id'] as int? ?? 0,
      timeOfDay: json['time_of_day'] as String? ?? '08:00',
      dosageDesc: json['dosage_desc'] as String?,
      isEnabled: json['is_enabled'] as bool? ?? true,
    );
  }
}

/// 用药记录（服药日志）
class MedicationLog {
  final int? id;
  final int medicationId;
  final int scheduleId;
  final String status;        // taken(已服) | skipped(跳过) | missed(漏服)
  final DateTime logDate;
  final String? takenAt;

  MedicationLog({
    this.id,
    required this.medicationId,
    required this.scheduleId,
    required this.status,
    required this.logDate,
    this.takenAt,
  });

  factory MedicationLog.fromJson(Map<String, dynamic> json) {
    return MedicationLog(
      id: json['id'] as int?,
      medicationId: json['medication_id'] as int? ?? 0,
      scheduleId: json['schedule_id'] as int? ?? 0,
      status: json['status'] as String? ?? 'missed',
      logDate: DateTime.parse(json['log_date'] as String? ?? DateTime.now().toIso8601String()),
      takenAt: json['taken_at'] as String?,
    );
  }
}
