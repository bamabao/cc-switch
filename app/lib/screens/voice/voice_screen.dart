import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// 语音助手全屏页 — P27
///
/// 核心：麦克风交互、语音识别状态、TTS回读确认
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  bool _isListening = false;
  String _recognizedText = '';
  String _responseText = '';

  void _onTapMic() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _recognizedText = '';
        _responseText = '';
      }
    });

    if (_isListening) {
      // 语音识别启动（后续由 VoiceService 实现）
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isListening = false;
            _recognizedText = '帮我看看今天的药';
            _responseText = '好的，您今天有 3 次服药安排：\n'
                '1. 阿莫西林胶囊 08:00 ✅ 已服\n'
                '2. 苯磺酸氨氯地平片 12:00 ⏳ 待服\n'
                '3. 阿托伐他汀钙片 20:00 ⏳ 待服';
          });
        }
      });
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
