import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

/// 设置页 — 方言语音切换、音量调节、个人信息
/// 对接后端 persist 用户偏好
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService();

  double _volume = 1.0;
  String _dialect = '普通话';
  bool _autoPlayVoice = true;
  bool _loading = true;

  static const List<String> _dialects = [
    '普通话', '粤语', '四川话', '上海话', '东北话',
  ];
  static const Map<String, String> _dialectToVoice = {
    '普通话': 'mandarin',
    '粤语': 'cantonese',
    '四川话': 'sichuan',
    '上海话': 'shanghai',
    '东北话': 'dongbei',
  };
  static const Map<String, String> _voiceToDialect = {
    'mandarin': '普通话',
    'cantonese': '粤语',
    'sichuan': '四川话',
    'shanghai': '上海话',
    'dongbei': '东北话',
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final user = await _api.getMe();
      if (!mounted) return;
      setState(() {
        _dialect = _voiceToDialect[user.voicePreference] ?? '普通话';
        _volume = user.fontScale != null ? (user.fontScale! / 100.0) : 1.0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveDialect(String dialect) async {
    final voicePref = _dialectToVoice[dialect] ?? 'mandarin';
    try {
      // 通过 PUT /auth/profile 保存
      await _api.put('${ApiConfig.authProfile}?voice_preference=$voicePref&token=${_api.token ?? ""}');
    } catch (_) {
      // 静默失败
    }
  }

  Future<void> _saveVolume(double volume) async {
    final fontScale = (volume * 100).round();
    try {
      await _api.put('${ApiConfig.authProfile}?font_scale=$fontScale&token=${_api.token ?? ""}');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              children: [
                _buildSection('语音设置', [
                  _buildSliderTile('语音播报音量', _volume, (v) {
                    setState(() => _volume = v);
                    _saveVolume(v);
                  }),
                  _buildDropdownTile('播报方言', _dialect, (v) {
                    if (v != null) {
                      setState(() => _dialect = v);
                      _saveDialect(v);
                    }
                  }),
                  _buildSwitchTile('自动语音播报', _autoPlayVoice, (v) {
                    setState(() => _autoPlayVoice = v);
                  }),
                ]),
                const SizedBox(height: AppTheme.spacingMd),
                _buildSection('个人信息', [
                  _buildActionTile('姓名', '点击修改'),
                  _buildActionTile('手机号', '138****8888'),
                  _buildActionTile('紧急联系人', '设置'),
                  _buildActionTile('常用药箱', '管理药品'),
                ]),
                const SizedBox(height: AppTheme.spacingMd),
                _buildSection('关于', [
                  _buildInfoTile('版本', 'v0.2.0'),
                  _buildInfoTile('用户协议', '查看'),
                  _buildInfoTile('隐私政策', '查看'),
                ]),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.spacingSm, bottom: AppTheme.spacingSm),
          child: Text(title, style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            boxShadow: AppTheme.shadowCard,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSliderTile(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textPrimary)),
          Slider(value: value, min: 0, max: 1, divisions: 10, activeColor: AppTheme.primaryColor,
            inactiveColor: AppTheme.primaryColor.withValues(alpha: 0.3),
            label: '${(value * 100).toInt()}%', onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(String label, String value, ValueChanged<String?> onChanged) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textPrimary)),
      trailing: DropdownButton<String>(
        value: value, underline: const SizedBox(),
        items: _dialects.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textPrimary)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSwitchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textPrimary)),
      trailing: Switch(value: value, activeColor: AppTheme.secondaryColor, onChanged: onChanged),
    );
  }

  Widget _buildActionTile(String label, String hint) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textPrimary)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(hint, style: const TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, size: 24, color: AppTheme.textSecondary),
      ]),
      onTap: () {},
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textPrimary)),
      trailing: Text(value, style: const TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary)),
    );
  }
}
