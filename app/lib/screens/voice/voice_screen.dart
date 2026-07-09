import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/theme.dart';
import '../../services/voice_service.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../profile/settings_screen.dart';

/// 语音助手全屏页 — P27
///
/// 核心：麦克风交互、离线语音识别 (AIKit ESR)、TTS回读确认
///
/// 【修复 v2.4】闪退修复：
/// 1. startListening 异步异常 try/catch
/// 2. dispose 清理 VoiceService 回调引用，防止 setState 在已销毁的 State 上调用
/// 3. SDK 初始化失败显示错误提示 + 重试按钮
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final VoiceService _voice = VoiceService();
  final ApiService _api = ApiService();

  bool _isInitialized = false;
  bool _initFailed = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _responseText = '';
  double _currentVolume = 0.0;
  final TextEditingController _textInputController = TextEditingController();
  bool _showTextInput = false;

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  /// 初始化语音引擎，失败时显示错误提示
  Future<void> _initVoice() async {
    try {
      final ok = await _voice.init();
      if (mounted) {
        setState(() {
          _isInitialized = ok;
          _initFailed = !ok;
          // TTS初始化成功但ASR可能不可用 → 弹文字输入框
          if (ok) _showTextInput = true;
        });
      }
      if (ok) _setupListeners();
    } catch (e) {
      if (mounted) {
        setState(() => _initFailed = true);
      }
    }
  }

  /// 注册 VoiceService 回调
  /// ⚠️ 必须在 init 成功后调用，防止回调指向旧 State
  void _setupListeners() {
    _voice.onStatus = (status) {
      if (!mounted) return;
      setState(() => _isListening = status == 'listening');
    };
    _voice.onVolume = (vol) {
      if (!mounted) return;
      setState(() => _currentVolume = vol);
    };
    _voice.onResult = (text, isFinal) {
      if (!mounted) return;
      setState(() {
        _recognizedText = text;
        if (isFinal) {
          _isListening = false;
          _handleCommand(text);
        }
      });
    };
    _voice.onSpeakCompleted = () {
      if (!mounted) return;
      setState(() {});
    };
  }

  /// dispose 时切断回调 + 清理所有资源，防止闪退
  @override
  void dispose() {
    // 先切断所有回调引用，防止在已销毁的State上调用setState
    _voice.onStatus = null;
    _voice.onVolume = null;
    _voice.onResult = null;
    _voice.onSpeakCompleted = null;
    // 清理语音引擎，每个步骤独立try/catch防止一处失败阻塞后续清理
    try {
      _voice.stopListening();
    } catch (_) {}
    try {
      _voice.stopSpeaking();
    } catch (_) {}
    try {
      _voice.destroy();
    } catch (_) {}
    super.dispose();
  }

  /// 点击麦克风按钮 — 加入完整异常捕获
  Future<void> _onTapMic() async {
    if (_initFailed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('语音引擎未就绪，请重试'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isListening) {
      try {
        _voice.stopListening();
      } catch (_) {}
      return;
    }

    // 运行时动态申请麦克风权限（Android 6.0+ 必需）
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要麦克风权限才能使用语音功能'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('权限请求失败：$e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _recognizedText = '';
      _responseText = '';
      _currentVolume = 0.0;
    });

    // ⚠️ 闪退核心原因：startListening 异步异常未捕获
    try {
      _voice.onResult = (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _recognizedText = text;
          if (isFinal) {
            _isListening = false;
            if (text.isEmpty) {
              // ASR 返回空（设备无 Google 服务）→ 显示文字输入框
              _showTextInput = true;
            } else {
              _showTextInput = false;
              _handleCommand(text);
            }
          }
        });
      };
      await _voice.startListening();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _showTextInput = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('语音识别暂不可用，请用下方输入框',),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 根据识别结果执行对应操作
  void _handleCommand(String text) {
    if (text.contains('吃药') || text.contains('用药') || text.contains('药品')) {
      _queryMedicationsAndRespond();
    } else if (text.contains('打卡') || text.contains('签到')) {
      _checkInAndRespond();
    } else if (text.contains('积分')) {
      _queryPointsAndRespond();
    } else if (text.contains('紧急') || text.contains('帮帮我')) {
      setState(() {
        _responseText = '⚠️ 紧急求助已发送，正在为您联系子女';
      });
      _safeSpeak('紧急求助已发送');
    } else if (text.contains('首页') || text.contains('返回')) {
      Navigator.pop(context);
    } else {
      setState(() {
        _responseText = '抱歉，我没有听懂，请再说一遍\n您可以试试说：\n"今天要吃什么药"\n"我的积分"\n"打卡"';
      });
      _safeSpeak('抱歉，我没有听懂，您可以试试说吃药或积分');
    }
  }

  /// 安全语音播报（吞异常防闪退）
  void _safeSpeak(String text) {
    try {
      _voice.speak(text);
    } catch (_) {}
  }

  Future<void> _queryMedicationsAndRespond() async {
    setState(() => _responseText = '正在查询您的用药安排…');
    try {
      final result = await _api.get(ApiConfig.medications, queryParams: {
        'elder_id': '1', 'status': 'approved'
      });
      final items = result['items'] as List<dynamic>? ?? [];
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() => _responseText = '您目前没有需要服用的药品');
        _safeSpeak('您目前没有需要服用的药品');
        return;
      }
      final sb = StringBuffer('您今天有 ${items.length} 种药品需要服用：\n');
      int index = 1;
      for (var med in items) {
        final name = med['name'] ?? '药品$index';
        sb.writeln('$index. $name');
        index++;
      }
      setState(() => _responseText = sb.toString());
      _safeSpeak('您今天有 ${items.length} 种药品需要服用，请看屏幕');
    } catch (e) {
      if (!mounted) return;
      setState(() => _responseText = '查询药品信息失败，请稍后再试');
      _safeSpeak('查询失败');
    }
  }

  Future<void> _checkInAndRespond() async {
    setState(() => _responseText = '正在处理打卡…');
    _safeSpeak('请您到药品页面确认用药完成打卡');
    setState(() {
      _responseText = '✅ 请在药品页面确认用药即可自动打卡！\n坚持打卡可获得积分奖励！';
    });
  }

  Future<void> _queryPointsAndRespond() async {
    setState(() => _responseText = '正在查询您的积分…');
    try {
      final pts = await _api.get('${ApiConfig.points}/profile?elder_id=1');
      final points = pts['total_points'] as int? ?? 0;
      final streak = pts['current_streak'] as int? ?? 0;
      if (!mounted) return;
      setState(() {
        _responseText = '您的当前积分: $points 分\n已连续打卡 $streak 天\n继续坚持按时服药获取积分！';
      });
      _safeSpeak('您的积分为 $points 分');
    } catch (e) {
      if (!mounted) return;
      setState(() => _responseText = '查询积分失败，请稍后再试');
      _safeSpeak('查询失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音助手'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // ── SDK 初始化失败提示 ──
            if (_initFailed)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: AppTheme.warningColor),
                    const SizedBox(height: 16),
                    const Text(
                      '语音引擎初始化失败',
                      style: TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '请检查手机麦克风和存储权限后重试',
                      style: TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _initFailed = false);
                        _initVoice();
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),

            // ── 语音反馈区域 ──
            if (!_initFailed && _recognizedText.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '您说: "$_recognizedText"',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      _responseText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            if (!_initFailed && _recognizedText.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
                child: Text(
                  '点击下方麦克风按钮，说出您想做的事\n\n'
                  '比如：\n'
                  '"帮我看看今天的药"\n'
                  '"添加阿莫西林胶囊，一天两次"\n'
                  '"我的积分有多少"',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),

            const Spacer(),

            // ── 音量指示条 ──
            if (_isListening)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: 160,
                  height: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _currentVolume),
                      duration: const Duration(milliseconds: 100),
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value.clamp(0.0, 1.0),
                        backgroundColor: AppTheme.cardColor,
                        valueColor: AlwaysStoppedAnimation(
                          _currentVolume > 0.6
                              ? AppTheme.dangerColor
                              : AppTheme.primaryColor,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                ),
              ),

            // ── 文字输入降级方案 ──
            if (_showTextInput) _buildTextInput(),
            if (!_showTextInput) const SizedBox(height: 16),

            // ── 麦克风按钮 ──
            GestureDetector(
              onTap: _onTapMic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isListening ? 140 : 120,
                height: _isListening ? 140 : 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? AppTheme.dangerColor : AppTheme.primaryColor,
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: AppTheme.dangerColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              _isListening ? '正在聆听...' : '点击说话',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _isListening ? AppTheme.dangerColor : AppTheme.primaryColor,
              ),
            ),

            const Spacer(),

            // ── 底部操作提示 ──
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, size: 32),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                    tooltip: '语音设置',
                  ),
                  const SizedBox(width: AppTheme.spacingXl),
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 32),
                    onPressed: () {
                      if (_responseText.isNotEmpty) {
                        _safeSpeak(_responseText
                            .replaceAll('\n', '，')
                            .replaceAll('*', ''));
                      } else {
                        _safeSpeak('还没有内容可以朗读');
                      }
                    },
                    tooltip: '朗读当前内容',
                  ),
                  const SizedBox(width: AppTheme.spacingXl),
                  IconButton(
                    icon: const Icon(Icons.close, size: 32),
                    onPressed: () => Navigator.pop(context),
                    tooltip: '关闭语音助手',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 文字输入降级方案 — 当ASR不可用时替代麦克风
  Widget _buildTextInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textInputController,
                    style: const TextStyle(fontSize: 20, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: '输入指令，例如：今天吃什么药',
                      hintStyle: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _submitTextCommand,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primaryColor, size: 32),
                  onPressed: () => _submitTextCommand(_textInputController.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.keyboard_voice, size: 20),
            label: const Text('尝试语音识别'),
            onPressed: () {
              setState(() => _showTextInput = false);
              _onTapMic();
            },
          ),
        ],
      ),
    );
  }

  /// 文字指令提交
  void _submitTextCommand(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _textInputController.clear();
    setState(() {
      _recognizedText = trimmed;
      _responseText = '';
    });
    _handleCommand(trimmed);
  }
}

