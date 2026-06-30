import 'package:flutter/services.dart';

/// 爸妈宝 — 语音服务
///
/// 通过 MethodChannel 与原生层（讯飞MSC SDK）通信
/// 封装：在线ASR、离线命令词、TTS播报、状态控制
///
/// 原生端需要实现：
///   Android: VoicePlugin.kt
///   iOS: VoicePlugin.swift
class VoiceService {
  static const _channel = MethodChannel('com.bamaobao/voice');

  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  /// 是否已初始化
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// 当前状态（保留用作状态追踪）
  // ignore: unused_field
  String _status = 'idle'; // idle | listening | speaking

  /// 初始化讯飞语音 SDK
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

  /// 设置语音识别参数
  ///
  /// [vadTimeout] 静音检测超时（毫秒），老人说话慢，建议 2000ms+
  /// [language] 语种，默认 "zh_cn"
  /// [accent] 方言，默认 "mandarin"，可选 "cantonese" "sichuan" 等
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

  /// 开始在线语音识别
  /// 返回识别文本
  Future<String> startListening() async {
    _status = 'listening';
    try {
      final result = await _channel.invokeMethod<String>('startListening');
      _status = 'idle';
      return result ?? '';
    } catch (e) {
      _status = 'idle';
      rethrow;
    }
  }

  /// 开始离线命令词识别
  /// 无网络时使用，返回匹配的关键词
  Future<String> startOfflineListening() async {
    _status = 'listening';
    try {
      final result = await _channel.invokeMethod<String>('startOfflineListening');
      _status = 'idle';
      return result ?? '';
    } catch (e) {
      _status = 'idle';
      rethrow;
    }
  }

  /// TTS 语音播报
  Future<void> speak(String text) async {
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
    await _channel.invokeMethod('stopSpeaking');
    _status = 'idle';
  }

  /// 停止录音/识别
  Future<void> stopListening() async {
    await _channel.invokeMethod('stopListening');
    _status = 'idle';
  }

  /// 释放资源
  Future<void> destroy() async {
    await _channel.invokeMethod('destroy');
    _initialized = false;
    _status = 'idle';
  }
}
