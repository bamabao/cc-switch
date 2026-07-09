package com.bamaobao.bamabao

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 爸妈宝 — 语音插件桥接 (Android 原生 TTS + SpeechRecognizer)
 *
 * 全方法 try-catch(Throwable) 保护，任何异常都不会导致 App 闪退。
 * 语音功能不可用时自动降级为文字输入。
 *
 * MethodChannel: com.bamaobao/voice
 */
class VoicePlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        private const val TAG = "VoicePlugin"
    }

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // ─── TTS ───
    private var tts: TextToSpeech? = null
    private val ttsInitialized = AtomicBoolean(false)
    private val ttsSpeaking = AtomicBoolean(false)

    // ─── ASR ───
    private var recognizer: SpeechRecognizer? = null
    private val asrAvailable = AtomicBoolean(false)
    private val asrListening = AtomicBoolean(false)

    // ═══════════════════════════════════════════════════════
    //              Flutter Plugin 生命周期
    // ═══════════════════════════════════════════════════════

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            channel = MethodChannel(binding.binaryMessenger, "com.bamaobao/voice")
            channel?.setMethodCallHandler(this)
            appContext = binding.applicationContext
        } catch (e: Throwable) {
            Log.e(TAG, "onAttachedToEngine 异常: ${e.message}")
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        destroyInternal()
        channel = null
        appContext = null
    }

    // ═══════════════════════════════════════════════════════
    //              MethodChannel 入口（全异常保护）
    // ═══════════════════════════════════════════════════════

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        try {
            when (call.method) {
                "init" -> handleInit(result)
                "setParams" -> safeResult(result, null)
                "startListening" -> handleStartListening(result)
                "startOfflineListening" -> handleStartListening(result)
                "speak" -> handleSpeak(call, result)
                "stopListening" -> handleStopListening(result)
                "stopSpeaking" -> handleStopSpeaking(result)
                "destroy" -> {
                    destroyInternal()
                    safeResult(result, null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            Log.e(TAG, "MethodCall 未捕获: ${e.message}")
            safeResult(result, null)
        }
    }

    private fun safeResult(result: Result, value: Any?) {
        try { result.success(value) } catch (_: Exception) {}
    }

    // ═══════════════════════════════════════════════════════
    //              1. 初始化（全异常保护）
    // ═══════════════════════════════════════════════════════

    private fun handleInit(result: Result) {
        if (ttsInitialized.get()) {
            safeResult(result, true)
            return
        }

        try {
            // 初始化 TTS
            tts = TextToSpeech(appContext) { status ->
                try {
                    if (status == TextToSpeech.SUCCESS) {
                        tts?.setLanguage(Locale.CHINESE)
                        tts?.setSpeechRate(0.9f)
                        tts?.setPitch(1.0f)

                        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                            override fun onStart(utteranceId: String?) {}
                            override fun onDone(utteranceId: String?) {
                                ttsSpeaking.set(false)
                                mainHandler.post {
                                    try {
                                        channel?.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
                                        channel?.invokeMethod("onStatus", mapOf("status" to "idle"))
                                    } catch (_: Exception) {}
                                }
                            }
                            override fun onError(utteranceId: String?) {
                                ttsSpeaking.set(false)
                                mainHandler.post {
                                    try {
                                        channel?.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
                                        channel?.invokeMethod("onStatus", mapOf("status" to "idle"))
                                    } catch (_: Exception) {}
                                }
                            }
                        })

                        ttsInitialized.set(true)
                        Log.i(TAG, "✅ TTS 初始化成功")
                        mainHandler.post { safeResult(result, true) }
                    } else {
                        Log.e(TAG, "❌ TTS 初始化失败: status=$status")
                        mainHandler.post { safeResult(result, false) }
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "TTS 回调异常: ${e.message}")
                    mainHandler.post { safeResult(result, false) }
                }
            }

            // 检测 ASR 是否可用
            try {
                val ctx = appContext
                if (ctx != null && SpeechRecognizer.isRecognitionAvailable(ctx)) {
                    asrAvailable.set(true)
                }
            } catch (_: Exception) {
                asrAvailable.set(false)
            }

        } catch (e: Throwable) {
            Log.e(TAG, "handleInit 异常: ${e.message}")
            ttsInitialized.set(false)
            mainHandler.post { safeResult(result, false) }
        }
    }

    // ═══════════════════════════════════════════════════════
    //              2. TTS 语音合成
    // ═══════════════════════════════════════════════════════

    private fun handleSpeak(call: MethodCall, result: Result) {
        if (!ttsInitialized.get()) {
            safeResult(result, null)
            return
        }

        val text = call.argument<String>("text") ?: ""
        if (text.isEmpty()) {
            safeResult(result, null)
            return
        }

        try {
            ttsSpeaking.set(true)
            channel?.invokeMethod("onStatus", mapOf("status" to "speaking"))
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "utt_${System.currentTimeMillis()}")
        } catch (e: Throwable) {
            Log.w(TAG, "TTS speak 异常: ${e.message}")
            ttsSpeaking.set(false)
            try {
                channel?.invokeMethod("onStatus", mapOf("status" to "idle"))
                channel?.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
            } catch (_: Exception) {}
        }

        safeResult(result, null)
    }

    private fun stopTts() {
        try { tts?.stop() } catch (_: Exception) {}
        ttsSpeaking.set(false)
    }

    // ═══════════════════════════════════════════════════════
    //              3. 语音识别 (SpeechRecognizer)
    // ═══════════════════════════════════════════════════════

    private fun handleStartListening(result: Result) {
        try {
            if (asrListening.get()) {
                safeResult(result, "already_listening")
                return
            }

            channel?.invokeMethod("onStatus", mapOf("status" to "listening"))

            if (!asrAvailable.get()) {
                // 没有 Google 服务 → 返回空，Flutter 侧显示文字输入框
                Log.w(TAG, "ASR 不可用，返回空结果")
                mainHandler.postDelayed({
                    try {
                        channel?.invokeMethod("onStatus", mapOf("status" to "idle"))
                        channel?.invokeMethod("onResult", mapOf("text" to "", "isFinal" to true))
                    } catch (_: Exception) {}
                    safeResult(result, "")
                }, 300)
                return
            }

            if (recognizer == null) {
                recognizer = SpeechRecognizer.createSpeechRecognizer(appContext)
            }

            recognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {
                    val vol = (rmsdB / 20.0f).coerceIn(0.0f, 1.0f)
                    mainHandler.post {
                        try { channel?.invokeMethod("onVolume", mapOf("volume" to vol.toDouble())) } catch (_: Exception) {}
                    }
                }
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) {
                    Log.w(TAG, "ASR 错误: $error")
                    asrListening.set(false)
                    mainHandler.post {
                        try {
                            channel?.invokeMethod("onStatus", mapOf("status" to "idle"))
                            channel?.invokeMethod("onResult", mapOf("text" to "", "isFinal" to true))
                        } catch (_: Exception) {}
                        safeResult(result, "")
                    }
                }
                override fun onResults(results: Bundle?) {
                    asrListening.set(false)
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val text = if (matches != null && matches.isNotEmpty()) matches[0] else ""
                    mainHandler.post {
                        try {
                            channel?.invokeMethod("onStatus", mapOf("status" to "idle"))
                            channel?.invokeMethod("onResult", mapOf("text" to text, "isFinal" to true))
                        } catch (_: Exception) {}
                        safeResult(result, text)
                    }
                }
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            asrListening.set(true)
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }
            recognizer?.startListening(intent)

        } catch (e: Throwable) {
            Log.e(TAG, "startListening 异常: ${e.message}")
            asrListening.set(false)
            mainHandler.post {
                try {
                    channel?.invokeMethod("onStatus", mapOf("status" to "idle"))
                    channel?.invokeMethod("onResult", mapOf("text" to "", "isFinal" to true))
                } catch (_: Exception) {}
                safeResult(result, "")
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    //              4. 停止操作
    // ═══════════════════════════════════════════════════════

    private fun handleStopListening(result: Result) {
        try {
            recognizer?.stopListening()
            recognizer?.destroy()
            recognizer = null
        } catch (_: Exception) {}
        asrListening.set(false)
        safeResult(result, null)
    }

    private fun handleStopSpeaking(result: Result) {
        stopTts()
        try {
            channel?.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
            channel?.invokeMethod("onStatus", mapOf("status" to "idle"))
        } catch (_: Exception) {}
        safeResult(result, null)
    }

    // ═══════════════════════════════════════════════════════
    //              5. 销毁
    // ═══════════════════════════════════════════════════════

    private fun destroyInternal() {
        try {
            recognizer?.stopListening()
            recognizer?.destroy()
        } catch (_: Exception) {}
        recognizer = null

        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {}
        tts = null

        ttsInitialized.set(false)
        ttsSpeaking.set(false)
        asrListening.set(false)
    }
}
