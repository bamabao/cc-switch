package com.bamaobao.bamabao

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册自定义语音插件（对接讯飞MSC SDK）
        flutterEngine.plugins.add(VoicePlugin())
    }
}
