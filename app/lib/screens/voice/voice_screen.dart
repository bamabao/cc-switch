import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/voice_service.dart';

/// 语音助手全屏页 — P27
///
/// 核心：麦克风交互、离线语音识别 (AIKit ESR)、TTS回读确认
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final VoiceService _voice = VoiceService();

  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _responseText = '';
  double _currentVolume = 0.0;

  @override
  void initState() {
    super.initState();
    _initVoice();
    _setupListeners();
  }

  Future<void> _initVoice() async {
    final ok = await _voice.init();
    if (mounted) {
      setState(() => _isInitialized = ok);
    }
  }

  void _setupListeners() {
    _voice.onStatus = (status) {
      if (mounted) {
        setState(() {
          _isListening = status == 'listening';
        });
      }
    };
    _voice.onVolume = (vol) {
      if (mounted) setState(() => _currentVolume = vol);
    };
    _voice.onResult = (text, isFinal) {
      if (mounted) {
        setState(() {
          _recognizedText = text;
          if (isFinal) {
            _isListening = false;
            _handleCommand(text);
          }
        });
      }
    };
    _voice.onSpeakCompleted = () {
      if (mounted) setState(() {});
    };
  }

  void _onTapMic() {
    if (!_isInitialized) return;

    if (_isListening) {
      _voice.stopListening();
    } else {
      setState(() {
        _recognizedText = '';
        _responseText = '';
        _currentVolume = 0.0;
      });
      _voice.startListening();
    }
  }

  /// 根据识别结果执行对应操作
  void _handleCommand(String text) {
    if (text.contains('吃药') || text.contains('用药') || text.contains('药品')) {
      _responseText = '好的，您今天有 3 次服药安排：\n'
          '1. 阿莫西林胶囊 08:00 ✅ 已服\n'
          '2. 苯磺酸氨氯地平片 12:00 ⏳ 待服\n'
          '3. 阿托伐他汀钙片 20:00 ⏳ 待服';
      _voice.speak('您今天有3次服药安排，请查看屏幕');
    } else if (text.contains('打卡') || text.contains('签到')) {
      _responseText = '✅ 今日已打卡签到！';
      _voice.speak('今日打卡签到成功');
    } else if (text.contains('积分')) {
      _responseText = '您的当前积分为: 1280 分';
      _voice.speak('您的积分为一千二百八十分');
    } else if (text.contains('紧急') || text.contains('帮帮我')) {
      _responseText = '⚠️ 已发送紧急求助！';
      _voice.speak('紧急求助已发送');
    } else if (text.contains('首页') || text.contains('返回')) {
      Navigator.pop(context);
    } else {
      _responseText = '抱歉，我没有听懂，请再说一遍';
      _voice.speak('抱歉，我没有听懂');
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

            // ── 语音反馈区域 ──
            if (_recognizedText.isNotEmpty) ...[
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

            if (_recognizedText.isEmpty)
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
                    onPressed: () {},
                    tooltip: '语音设置',
                  ),
                  const SizedBox(width: AppTheme.spacingXl),
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 32),
                    onPressed: () {},
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
}
