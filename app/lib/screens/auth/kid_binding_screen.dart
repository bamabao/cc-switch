import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// 首次开机子女绑定流程 — 家人绑定引导
/// P0新增强制：首次开机配对
/// v2黏土软萌风格
class KidBindingScreen extends StatefulWidget {
  const KidBindingScreen({super.key});

  @override
  State<KidBindingScreen> createState() => _KidBindingScreenState();
}

class _KidBindingScreenState extends State<KidBindingScreen> {
  int _currentStep = 0;
  final TextEditingController _phoneController = TextEditingController();

  static const List<String> _stepLabels = [
    '开始',
    '扫码',
    '手机号',
    '完成',
  ];

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('家人绑定'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 步骤进度条
          _buildStepIndicator(),
          // 步骤内容
          Expanded(child: _buildStepContent()),
          // 底部按钮
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLg,
        vertical: AppTheme.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        boxShadow: AppTheme.shadowCard,
      ),
      child: Row(
        children: List.generate(
          _stepLabels.length,
          (i) => Expanded(
            child: _buildStepDot(i),
          ),
        ),
      ),
    );
  }

  Widget _buildStepDot(int index) {
    final bool isActive = index == _currentStep;
    final bool isDone = index < _currentStep;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDone || isActive
                ? AppTheme.primaryColor
                : AppTheme.textSecondary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 24)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: AppTheme.bodyLarge,
                      color: isActive ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _stepLabels[index],
          style: TextStyle(
            fontSize: AppTheme.bodyMedium,
            color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepWelcome();
      case 1:
        return _buildStepQR();
      case 2:
        return _buildStepPhone();
      case 3:
        return _buildStepComplete();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepWelcome() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.family_restroom,
              size: 100, color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          const Text(
            '让子女帮您管理用药，\n更加省心',
            style: TextStyle(
              fontSize: AppTheme.headlineMedium,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            '绑定后子女可以查看您的\n用药记录、添加提醒、接收漏服通知',
            style: TextStyle(
              fontSize: AppTheme.bodyLarge,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            '也可以跳过，稍后再说',
            style: TextStyle(
              fontSize: AppTheme.bodyMedium,
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepQR() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner,
              size: 100, color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          const Text(
            '请子女用微信扫码',
            style: TextStyle(
              fontSize: AppTheme.headlineMedium,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            '扫码后子女可在手机上\n查看您的用药情况',
            style: TextStyle(
              fontSize: AppTheme.bodyLarge,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // 模拟二维码区域
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: AppTheme.shadowCard,
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code,
                      size: 120, color: AppTheme.textPrimary),
                  SizedBox(height: 4),
                  Text(
                    '扫一扫，绑定家人',
                    style: TextStyle(
                      fontSize: AppTheme.bodyMedium,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPhone() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.phone_android,
              size: 80, color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          const Text(
            '或者输入子女的手机号',
            style: TextStyle(
              fontSize: AppTheme.headlineMedium,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            '输入子女手机号后，我们会\n发送邀请短信',
            style: TextStyle(
              fontSize: AppTheme.bodyLarge,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              boxShadow: AppTheme.shadowCard,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: 4,
            ),
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                fontSize: AppTheme.titleLarge,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '输入子女手机号',
                hintStyle: TextStyle(
                  fontSize: AppTheme.titleLarge,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: AppTheme.buttonHeight,
            child: ElevatedButton(
              onPressed: _phoneController.text.length == 11 ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor:
                    AppTheme.cardColor.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusButton),
                ),
              ),
              child: const Text(
                '发送邀请',
                style: TextStyle(
                  fontSize: AppTheme.titleMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepComplete() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: AppTheme.secondaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            '🎉 绑定成功',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '用药提醒将同步通知给子女',
            style: TextStyle(
              fontSize: AppTheme.bodyLarge,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '子女可以帮您添加药品、查看记录',
            style: TextStyle(
              fontSize: AppTheme.bodyLarge,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        boxShadow: AppTheme.shadowElevated,
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: SizedBox(
                  height: AppTheme.buttonHeight,
                  child: OutlinedButton(
                    onPressed:
                        _currentStep == 3 ? null : _prevStep,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                      ),
                    ),
                    child: Text(
                      _currentStep == 3 ? '' : '上一步',
                      style: const TextStyle(
                        fontSize: AppTheme.titleMedium,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: AppTheme.buttonHeight,
                child: ElevatedButton(
                  onPressed: _currentStep >= 3
                      ? _finish
                      : (_currentStep == 0
                          ? _nextStep
                          : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textOnDark,
                    disabledBackgroundColor:
                        AppTheme.cardColor.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusButton),
                    ),
                    textStyle: const TextStyle(
                      fontSize: AppTheme.titleMedium,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: AppTheme.textPrimary,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  child: Text(_currentStep >= 3 ? '开始使用' : '开始绑定'),
                ),
              ),
            ),
            if (_currentStep == 0) ...[
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: AppTheme.buttonHeight,
                  child: OutlinedButton(
                    onPressed: _finish,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                      ),
                    ),
                    child: const Text(
                      '跳过',
                      style: TextStyle(
                        fontSize: AppTheme.titleMedium,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
