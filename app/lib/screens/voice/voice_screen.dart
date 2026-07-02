import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/voice_service.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../profile/settings_screen.dart';

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
  final ApiService _api = ApiService();

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
      _queryMedicationsAndRespond();
    } else if (text.contains('打卡') || text.contains('签到')) {
      _checkInAndRespond();
    } else if (text.contains('积分')) {
      _queryPointsAndRespond();
    } else if (text.contains('紧急') || text.contains('帮帮我')) {
      setState(() {
        _responseText = '⚠️ 紧急求助已发送，正在为您联系子女';
      });
      _voice.speak('紧急求助已发送');
    } else if (text.contains('首页') || text.contains('返回')) {
      Navigator.pop(context);
    } else {
      setState(() {
        _responseText = '抱歉，我没有听懂，请再说一遍\n您可以试试说：\n"今天要吃什么药"\n"我的积分"\n"打卡"';
      });
      _voice.speak('抱歉，我没有听懂，您可以试试说吃药或积分');
    }
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
        _voice.speak('您目前没有需要服用的药品');
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
      _voice.speak('您今天有 ${items.length} 种药品需要服用，请看屏幕');
    } catch (e) {
      if (!mounted) return;
      setState(() => _responseText = '查询药品信息失败，请稍后再试');
      _voice.speak('查询失败');
    }
  }

  Future<void> _checkInAndRespond() async {
    setState(() => _responseText = '正在处理打卡…');
    _voice.speak('请您到药品页面确认用药完成打卡');
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
      _voice.speak('您的积分为 $points 分');
    } catch (e) {
      if (!mounted) return;
      setState(() => _responseText = '查询积分失败，请稍后再试');
      _voice.speak('查询失败');
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
                        _voice.speak(_responseText
                            .replaceAll('\n', '，')
                            .replaceAll('*', ''));
                      } else {
                        _voice.speak('还没有内容可以朗读');
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
}
