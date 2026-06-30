import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import 'kid_binding_screen.dart';
import '../../main.dart';

/// 登录注册页 — 仅手机号验证码登录
/// P0-3：老年友好 + 家属协助
/// v2黏土软萌风格
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _codeFocus = FocusNode();
  final ApiService _api = ApiService();

  int _countdown = 0;
  bool _sendingCode = false;
  bool _loggingIn = false;
  bool _agreePolicy = false;
  String? _errorMsg;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  bool get _canGetCode =>
      _phoneController.text.length == 11 && _countdown == 0 && !_sendingCode;

  bool get _canLogin =>
      _codeController.text.length >= 4 &&
      _phoneController.text.length == 11 &&
      _agreePolicy;

  void _startCountdown() {
    setState(() => _countdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        }
      });
      return _countdown > 0 && mounted;
    });
  }

  void _sendCode() async {
    if (!_canGetCode) return;
    setState(() {
      _sendingCode = true;
      _errorMsg = null;
    });
    try {
      await _api.sendSmsCode(_phoneController.text);
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _errorMsg = null;
      });
      _startCountdown();
      _codeFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('验证码已发送，60秒内有效'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _errorMsg = '发送失败，请检查网络后重试';
      });
    }
  }

  void _login() async {
    if (!_canLogin || _loggingIn) return;
    setState(() {
      _loggingIn = true;
      _errorMsg = null;
    });
    try {
      await _api.login(_phoneController.text, _codeController.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loggingIn = false;
        _errorMsg = '登录失败，请检查手机号和验证码';
      });
    }
  }

  void _goKidBinding() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const KidBindingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // 标题
              Text(
                '欢迎使用爸妈宝',
                style: TextStyle(
                  fontSize: AppTheme.headlineLarge,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '请输入您的手机号，\n我们会发一条短信验证码',
                style: TextStyle(
                  fontSize: AppTheme.bodyLarge,
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 手机号输入框
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
                child: Row(
                  children: [
                    Text(
                      '+86',
                      style: TextStyle(
                        fontSize: AppTheme.titleMedium,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('|',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        style: TextStyle(
                          fontSize: AppTheme.titleLarge,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: '输入手机号码',
                          hintStyle: TextStyle(
                            fontSize: AppTheme.titleLarge,
                            color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 验证码 + 获取按钮
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                        boxShadow: AppTheme.shadowCard,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: _codeController,
                        focusNode: _codeFocus,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        style: TextStyle(
                          fontSize: AppTheme.titleLarge,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: '输入短信里的数字',
                          hintStyle: TextStyle(
                            fontSize: AppTheme.titleLarge,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: AppTheme.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _canGetCode ? _sendCode : null,
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor:
                            AppTheme.cardColor.withValues(alpha: 0.6),
                        disabledForegroundColor:
                            AppTheme.textSecondary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusButton),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        _sendingCode
                            ? '发送中…'
                            : _countdown > 0
                                ? '${_countdown}s'
                                : '获取验证码',
                        style: TextStyle(
                          fontSize: AppTheme.bodyLarge,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 协议勾选
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _agreePolicy = !_agreePolicy),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _agreePolicy
                            ? AppTheme.secondaryColor
                            : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _agreePolicy
                              ? AppTheme.secondaryColor
                              : AppTheme.textSecondary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: _agreePolicy
                          ? const Icon(Icons.check, size: 20, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '登录即表示同意《用户协议》和《隐私政策》',
                      style: TextStyle(
                        fontSize: AppTheme.bodyMedium,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 错误提示
              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMsg!,
                    style: TextStyle(
                      fontSize: AppTheme.bodyMedium,
                      color: AppTheme.dangerColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // 登录按钮
              SizedBox(
                height: AppTheme.buttonHeight,
                child: ElevatedButton(
                  onPressed: (_canLogin && !_loggingIn) ? _login : null,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor:
                        AppTheme.cardColor.withValues(alpha: 0.6),
                    disabledForegroundColor:
                        AppTheme.textSecondary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusButton),
                    ),
                    textStyle: TextStyle(
                      fontSize: AppTheme.titleMedium,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(
                          color: AppTheme.textPrimary,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  child: _loggingIn
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text('开始使用'),
                ),
              ),
              const SizedBox(height: 24),

              // 家属协助注册兜底入口
              Center(
                child: TextButton.icon(
                  onPressed: _goKidBinding,
                  icon: Icon(Icons.family_restroom,
                      size: AppTheme.iconSize, color: AppTheme.primaryColor),
                  label: Text(
                    '需要子女帮忙？  家属协助注册',
                    style: TextStyle(
                      fontSize: AppTheme.bodyLarge,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
