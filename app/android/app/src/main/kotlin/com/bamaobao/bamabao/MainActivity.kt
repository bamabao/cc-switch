package com.bamaobao.bamabao

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册语音插件（Android原生TTS/ASR，全异常保护）
        try {
            flutterEngine.plugins.add(VoicePlugin())
        } catch (e: Throwable) {
            android.util.Log.e("MainActivity", "VoicePlugin注册失败: ${e.message}")
        }
    }
}
