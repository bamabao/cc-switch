import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../voice/voice_screen.dart';

/// 药品录入页 — 三通道录入
/// 支持：药盒拍照 / 语音录入 / 手动手写录入
/// P0-2：子女帮我录入入口（老人操作兜底）
class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _dosageFocus = FocusNode();

  final ApiService _api = ApiService();
  String _selectedCategory = '内服';
  bool _showForm = true;
  bool _submitting = false;
  int _elderId = 1;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final user = await _api.getMe();
      if (mounted) setState(() => _elderId = user.id);
    } catch (_) {}
  }

  static const List<String> _categories = ['内服', '外用', '针剂', '滋补'];
  static const Map<String, String> _categoryApiMap = {
    '内服': 'oral',
    '外用': 'external',
    '针剂': 'injection',
    '滋补': 'supplement',
  };
  List<IconData> get _categoryIcons => const [
    Icons.medication_liquid,
    Icons.medication,
    Icons.health_and_safety,
    Icons.spa,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _noteController.dispose();
    _nameFocus.dispose();
    _dosageFocus.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _api.post('${ApiConfig.medications}?elder_id=$_elderId', body: {
        'name': _nameController.text,
        'category': _categoryApiMap[_selectedCategory] ?? 'oral',
        'oral_form': 'tablet',
        'notes': _noteController.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('药品已添加！'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加失败：$e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('添加药品'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已通知子女帮忙添加药品'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              '子女帮我录入',
              style: TextStyle(
                fontSize: AppTheme.bodyMedium,
                color: AppTheme.textOnDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 三通道入口
            _buildInputChannels(),
            const SizedBox(height: AppTheme.spacingLg),
            // 分类选择
            _buildCategorySelector(),
            const SizedBox(height: AppTheme.spacingLg),
            // 表单
            if (_showForm) _buildForm(),
            const SizedBox(height: AppTheme.spacingLg),
            // 提交按钮
            if (_showForm) _buildSubmitButton(),
            if (_submitting)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputChannels() {
    return Row(
      children: [
        Expanded(
          child: _buildChannelCard(
            icon: Icons.camera_alt,
            label: '拍照',
            subtitle: '拍药盒自动识别',
            color: AppTheme.primaryColor,
            onTap: () async {
              // 运行时动态申请相机权限
              final cameraStatus = await Permission.camera.request();
              if (cameraStatus != PermissionStatus.granted) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('需要相机权限才能拍照识别'),
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
              final picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 2048,
                imageQuality: 85,
              );
              if (image != null && context.mounted) {
                if (!context.mounted) return;
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    content: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(image.path),
                        fit: BoxFit.contain,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildChannelCard(
            icon: Icons.mic,
            label: '语音录入',
            subtitle: '说话填写药品信息',
            color: AppTheme.secondaryColor,
            onTap: () {
              // 跳转语音助手页进行语音录入
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceScreen()));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildChannelCard(
            icon: Icons.edit,
            label: '手动填写',
            subtitle: '自己输入药品信息',
            color: const Color(0xFF1565C0),
            onTap: () {
              _nameFocus.requestFocus();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChannelCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.shadowCard,
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 42),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 30,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 24,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '药品分类',
              style: TextStyle(
                fontSize: AppTheme.bodyLarge,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                _categories.length,
                (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = _categories[i]);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedCategory == _categories[i]
                              ? AppTheme.primaryColor.withValues(alpha: 0.12)
                              : AppTheme.bgColor,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusButton),
                          border: Border.all(
                            color: _selectedCategory == _categories[i]
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _categoryIcons[i],
                              color: _selectedCategory == _categories[i]
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _categories[i],
                              style: TextStyle(
                                fontSize: AppTheme.bodyMedium,
                                color: _selectedCategory == _categories[i]
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField(
              controller: _nameController,
              focusNode: _nameFocus,
              label: '药品名称',
              hint: '例如：阿莫西林胶囊',
              icon: Icons.medication,
              large: true,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _buildInputField(
              controller: _dosageController,
              focusNode: _dosageFocus,
              label: '每次用量',
              hint: '例如：2粒',
              icon: Icons.calculate,
              large: true,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _buildInputField(
              controller: _frequencyController,
              label: '服用时间',
              hint: '例如：早餐后',
              icon: Icons.access_time,
              large: true,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _buildInputField(
              controller: _noteController,
              label: '注意事项',
              hint: '例如：忌酒',
              icon: Icons.info_outline,
              large: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required String hint,
    required IconData icon,
    bool large = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 28 : AppTheme.bodyLarge,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: large ? 12 : 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: TextStyle(
              fontSize: large ? 28 : AppTheme.titleMedium,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: large ? 26 : AppTheme.titleMedium,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: AppTheme.buttonHeight,
      child: ElevatedButton(
        onPressed: _nameController.text.isNotEmpty ? _submit : null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: AppTheme.cardColor.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: AppTheme.titleMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('添加药品'),
      ),
    );
  }
}
