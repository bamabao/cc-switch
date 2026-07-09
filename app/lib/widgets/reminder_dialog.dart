import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../config/theme.dart';
import '../../services/voice_service.dart';
import '../models/medication_dose.dart';

/// 爸妈宝 — 服药提醒选择弹窗（三种模式 + 语音称谓）
/// 保存/新增服药时间后自动弹出，不可跳过
class ReminderDialog extends StatefulWidget {
  final String medicationName;
  final ValueChanged<MedicationDose> onConfirm;

  const ReminderDialog({
    super.key,
    required this.medicationName,
    required this.onConfirm,
  });

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  ReminderType _selectedType = ReminderType.systemAlarm;
  String? _selectedVoiceTitle;
  String? _selectedMusicPath;

  static const List<String> _voiceTitles = [
    '爸爸', '妈妈', '爷爷', '奶奶', '宝宝', '帅哥', '靓妹',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请选择提醒方式', style: TextStyle(fontSize: AppTheme.headlineMedium, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('选择后系统将在您设置的时段自动提醒', style: TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary)),
            const SizedBox(height: AppTheme.spacingMd),

            // ─── 三种提醒模式 ───
            _buildRadioOption(
              icon: Icons.alarm,
              title: '系统闹铃',
              subtitle: '锁屏后台仍可触发',
              value: ReminderType.systemAlarm,
            ),
            _buildRadioOption(
              icon: Icons.music_note,
              title: '自定义背景音乐',
              subtitle: '选择本地音频文件',
              value: ReminderType.backgroundMusic,
            ),
            _buildRadioOption(
              icon: Icons.record_voice_over,
              title: '讯飞语音真人播报',
              subtitle: '真人语音循环朗读提醒',
              value: ReminderType.voiceBroadcast,
            ),

            // ─── 语音播报称谓选择（仅语音播报模式显示） ───
            if (_selectedType == ReminderType.voiceBroadcast) ...[
              const SizedBox(height: AppTheme.spacingMd),
              const Divider(color: AppTheme.textSecondary),
              const SizedBox(height: 8),
              const Text('选择播报称呼', style: TextStyle(fontSize: AppTheme.bodyLarge, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _voiceTitles.map((title) {
                  final selected = _selectedVoiceTitle == title;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedVoiceTitle = title);
                      // 示例播报
                      VoiceService().speak('$title，该吃药了，请按时服用${widget.medicationName}');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.secondaryColor : AppTheme.bgColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: selected ? AppTheme.secondaryColor : AppTheme.textSecondary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: AppTheme.bodyLarge,
                          color: selected ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // ─── 背景音乐路径显示 ───
            if (_selectedType == ReminderType.backgroundMusic && _selectedMusicPath != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack, color: AppTheme.primaryColor, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMusicPath!.split('/').last.split('\\').last,
                        style: const TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedMusicPath = null),
                      child: const Icon(Icons.close, color: AppTheme.warningColor, size: 24),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppTheme.spacingMd),

            // ─── 确定按钮 ───
            SizedBox(
              width: double.infinity,
              height: AppTheme.buttonHeight,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                ),
                child: const Text('确认提醒', style: TextStyle(fontSize: AppTheme.titleMedium, color: AppTheme.textOnDark, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required ReminderType value,
  }) {
    final selected = _selectedType == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedType = value);
          if (value == ReminderType.backgroundMusic) {
            _pickMusic();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: selected ? AppTheme.secondaryColor.withValues(alpha: 0.1) : AppTheme.bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected ? AppTheme.secondaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.secondaryColor : AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: selected ? Colors.white : AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: AppTheme.bodyLarge, fontWeight: FontWeight.w600, color: selected ? AppTheme.secondaryColor : AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: AppTheme.bodySmall, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppTheme.secondaryColor : Colors.transparent,
                  border: Border.all(color: selected ? AppTheme.secondaryColor : AppTheme.textSecondary, width: 2.5),
                ),
                child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMusic() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedMusicPath = result.files.single.path);
    }
  }

  void _confirm() {
    if (_selectedType == ReminderType.voiceBroadcast && _selectedVoiceTitle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择一个播报称呼'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    Navigator.pop(context);
    widget.onConfirm(MedicationDose(
      reminderType: _selectedType,
      voiceTitle: _selectedVoiceTitle,
      musicPath: _selectedMusicPath,
    ));
  }
}
