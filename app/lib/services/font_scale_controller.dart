import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局长辈模式（大字模式）控制器
/// 开启后全局字号放大 1.25 倍
class FontScaleController {
  FontScaleController._();
  static final FontScaleController instance = FontScaleController._();

  /// 当前字号倍率（1.0 普通 / 1.25 长辈模式）
  final ValueNotifier<double> scale = ValueNotifier(1.0);

  static const String _key = 'elderly_mode';

  /// 是否长辈模式
  bool get isElderly => scale.value > 1.0;

  /// 启动时读取
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_key) ?? false;
      scale.value = enabled ? 1.25 : 1.0;
    } catch (_) {}
  }

  /// 切换长辈模式
  Future<void> setElderly(bool enabled) async {
    scale.value = enabled ? 1.25 : 1.0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (_) {}
  }
}
