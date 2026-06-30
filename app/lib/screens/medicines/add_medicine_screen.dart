import 'package:flutter/material.dart';
import '../../config/theme.dart';

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

  String _selectedCategory = '内服';
  bool _showForm = true;

  static const List<String> _categories = ['内服', '外用', '针剂', '滋补'];
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

  void _submit() {
    // TODO: 调用后端保存药品API
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('药品已添加！'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('添加药品'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
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
            onTap: () {
              // TODO: 调用相机/相册
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在打开相机…')),
              );
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
              // TODO: 语音识别录入
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请说出药品名称和用量…')),
              );
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
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.shadowCard,
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.bodyLarge,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: AppTheme.bodyMedium,
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
            Text(
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
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _buildInputField(
              controller: _dosageController,
              focusNode: _dosageFocus,
              label: '每次用量',
              hint: '例如：2粒',
              icon: Icons.calculate,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _buildInputField(
              controller: _frequencyController,
              label: '服用时间',
              hint: '例如：早餐后',
              icon: Icons.access_time,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _buildInputField(
              controller: _noteController,
              label: '注意事项',
              hint: '例如：忌酒',
              icon: Icons.info_outline,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.bodyLarge,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: TextStyle(
              fontSize: AppTheme.titleMedium,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: AppTheme.titleMedium,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
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
          textStyle: TextStyle(
            fontSize: AppTheme.titleMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('添加药品'),
      ),
    );
  }
}
