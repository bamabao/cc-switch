import 'dart:async';
import 'package:flutter/services.dart';

/// 爸妈宝 — 离线语音服务 (AIKit SDK)
///
/// 通过 MethodChannel 与原生层 (AIKit 离线引擎) 通信
/// 封装: 离线语音合成 (TTS) + 离线命令词识别 (ESR)
///
/// 类型别名 — 语音事件回调
typedef OnStatusCallback = void Function(String status);
typedef OnVolumeCallback = void Function(double volume);
typedef OnResultCallback = void Function(String text, bool isFinal);
typedef OnSpeakCompletedCallback = void Function();

class VoiceService {
  static const _channel = MethodChannel('com.bamaobao/voice');

  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  // ─── 状态 ───
  bool _initialized = false;
  bool get isInitialized => _initialized;
  String _status = 'idle';
  String get status => _status;

  // ─── 事件回调注册 ───
  OnStatusCallback? onStatus;
  OnVolumeCallback? onVolume;
  OnResultCallback? onResult;
  OnSpeakCompletedCallback? onSpeakCompleted;

  /// 处理原生层发来的事件
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onStatus':
          final s = call.arguments['status'] as String? ?? 'idle';
          _status = s;
          onStatus?.call(s);
        case 'onVolume':
          onVolume?.call((call.arguments['volume'] as num?)?.toDouble() ?? 0.0);
        case 'onResult':
          final text = call.arguments['text'] as String? ?? '';
          final isFinal = call.arguments['isFinal'] as bool? ?? false;
          onResult?.call(text, isFinal);
        case 'onSpeakCompleted':
          _status = 'idle';
          onSpeakCompleted?.call();
      }
    } catch (e) {
      print('VoiceService native call 异常（非致命）: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  //  公共 API
  // ═══════════════════════════════════════════════════════════

  /// 初始化 AIKit 离线语音引擎
  Future<bool> init() async {
    try {
      final result = await _channel.invokeMethod<bool>('init');
      _initialized = result ?? false;
      return _initialized;
    } catch (_) {
      _initialized = false;
      return false;
    }
  }

  /// 设置语音识别参数（离线模式暂无运行时参数）
  Future<void> setParams({
    int vadTimeout = 2000,
    String language = 'zh_cn',
    String accent = 'mandarin',
  }) async {
    await _channel.invokeMethod('setParams', {
      'vad_timeout': vadTimeout,
      'language': language,
      'accent': accent,
    });
  }

  /// 开始语音识别（离线命令词模式）
  ///
  /// 返回匹配到的命令词文本。
  /// 识别过程中通过 [onResult] 回调获取中间结果，
  /// 通过 [onVolume] 获取实时音量。
  ///
  /// ⚠️ 超时保护：20秒后自动停止（防止Native端永不回调导致页面假死）
  Future<String> startListening() async {
    if (!_initialized) {
      _status = 'idle';
      return '';
    }
    _status = 'listening';
    try {
      final result = await _channel
          .invokeMethod<String>('startListening')
          .timeout(const Duration(seconds: 20), onTimeout: () {
        // 超时保护：停止录音并返回空串，防止页面卡死
        try {
          _channel.invokeMethod('stopListening');
        } catch (_) {}
        _status = 'idle';
        return '';
      });
      _status = 'idle';
      return result ?? '';
    } catch (e) {
      _status = 'idle';
      rethrow;
    }
  }

  /// 开始离线命令词识别（与 startListening 等效）
  Future<String> startOfflineListening() async {
    _status = 'listening';
    try {
      final result =
          await _channel.invokeMethod<String>('startOfflineListening');
      _status = 'idle';
      return result ?? '';
    } catch (e) {
      _status = 'idle';
      rethrow;
    }
  }

  /// TTS 语音播报
  ///
  /// 播报过程中通过 [onStatus] 回调通知 "speaking" 状态，
  /// 完成后通过 [onSpeakCompleted] 回调通知。
  Future<void> speak(String text) async {
    if (!_initialized) return;
    _status = 'speaking';
    try {
      await _channel.invokeMethod('speak', {'text': text});
    } catch (e) {
      _status = 'idle';
      rethrow;
    }
  }

  /// 停止播报
  Future<void> stopSpeaking() async {
    try {
      await _channel.invokeMethod('stopSpeaking');
    } catch (_) {}
    _status = 'idle';
  }

  /// 停止录音/识别
  Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
    _status = 'idle';
  }

  /// 释放资源
  Future<void> destroy() async {
    try {
      await _channel.invokeMethod('destroy');
    } catch (_) {
      // dispose 阶段调用，吞掉所有异常防止闪退
    }
    _initialized = false;
    _status = 'idle';
  }
}
