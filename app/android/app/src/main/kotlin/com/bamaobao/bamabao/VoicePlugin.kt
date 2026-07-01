package com.bamaobao.bamabao

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * 爸妈宝 — 语音插件桥接 (Mock版)
 *
 * 当前状态：Mock实现，模拟语音识别和TTS
 *
 * 讯飞SDK集成待下载MSC完整SDK后替换：
 * - 在线ASR: com.iflytek.cloud.SpeechRecognizer
 * - 在线TTS: com.iflytek.cloud.SpeechSynthesizer
 * - AIKit离线: com.iflytek.aikit.*
 *
 * APPID已在AndroidManifest.xml配置: 2d77802d
 * 下载地址: https://console.xfyun.cn/services/iat → 下载SDK
 */
class VoicePlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        private const val TAG = "VoicePlugin"
        private const val SAMPLE_RATE = 16000
        private const val BUFFER_SIZE = 1280
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val mainHandler = Handler(Looper.getMainLooper())

    // 录音
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingThread: Thread? = null

    // 状态
    private var isListening = false
    private var isSpeaking = false

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.bamaobao/voice")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "setParams" -> handleSetParams(call, result)
            "startListening" -> handleStartListening(call, result)
            "startOfflineListening" -> handleStartOfflineListening(call, result)
            "speak" -> handleSpeak(call, result)
            "stopListening" -> handleStopListening(call, result)
            "stopSpeaking" -> handleStopSpeaking(call, result)
            "destroy" -> handleDestroy(call, result)
            else -> result.notImplemented()
        }
    }

    // ═══════════════════════════ 初始化 ═══════════════════════════

    private fun handleInit(call: MethodCall, result: Result) {
        try {
            // Mock: 语音引擎初始化成功模拟
            // TODO: 替换为真实初始化
            // SpeechUtility.createUtility(context, SpeechConstant.APPID + "=2d77802d")
            Log.d(TAG, "语音引擎初始化成功 (Mock)")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "初始化异常: ${e.message}")
            result.success(false)
        }
    }

    private fun handleSetParams(call: MethodCall, result: Result) {
        result.success(null)
    }

    // ═══════════════════════════ 语音识别 (Mock) ═══════════════════════════

    private fun handleStartListening(call: MethodCall, result: Result) {
        if (isListening) {
            result.success("already_listening")
            return
        }
        isListening = true
        startRecording()

        channel.invokeMethod("onStatus", mapOf("status" to "listening"))

        // Mock: 模拟2秒后返回识别结果
        // TODO: 替换为真实在线ASR
        // val recognizer = SpeechRecognizer.createRecognizer(context)
        // recognizer.startListening(recognizerListener)
        mainHandler.postDelayed({
            if (!isListening) return@postDelayed
            val mockTexts = listOf(
                "帮我看看今天的药", "打卡签到", "呼叫医生", "我的积分",
                "添加药品", "打开设置", "积分商城", "紧急求助",
                "返回首页", "用药记录", "查看药品列表"
            )
            val mockResult = mockTexts.random()
            channel.invokeMethod("onResult", mapOf(
                "text" to mockResult,
                "isFinal" to true
            ))
            isListening = false
            stopRecording()
            channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        }, 2000)

        result.success("recording_started")
    }

    // ═══════════════════════════ 离线命令词 (Mock) ═══════════════════════════

    private fun handleStartOfflineListening(call: MethodCall, result: Result) {
        // TODO: 替换为AIKit离线命令词识别
        channel.invokeMethod("onStatus", mapOf("status" to "listening"))
        mainHandler.postDelayed({
            channel.invokeMethod("onResult", mapOf(
                "text" to "帮我看看今天的药",
                "isFinal" to true
            ))
            channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        }, 1500)
        result.success("offline_recording_started")
    }

    // ═══════════════════════════ 语音合成 (Mock) ═══════════════════════════

    private fun handleSpeak(call: MethodCall, result: Result) {
        val text = call.argument<String>("text") ?: ""

        if (text.isEmpty()) {
            result.error("EMPTY_TEXT", "播报文本为空", null)
            return
        }

        if (isSpeaking) {
            stopSpeakingInternal()
        }

        isSpeaking = true
        mockSpeak(text)
        result.success(null)
    }

    /** Mock语音（每个字模拟100ms） */
    private fun mockSpeak(text: String) {
        val delayMs = (text.length * 100L).coerceIn(500, 8000)
        channel.invokeMethod("onStatus", mapOf("status" to "speaking"))
        mainHandler.postDelayed({
            isSpeaking = false
            channel.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
            channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        }, delayMs)
    }

    // ═══════════════════════════ 录音 ═══════════════════════════

    private fun startRecording() {
        if (isRecording) return
        try {
            val minBufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(BUFFER_SIZE)

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                minBufferSize
            )
            audioRecord?.startRecording()
            isRecording = true

            recordingThread = Thread {
                android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
                val buffer = ByteArray(minBufferSize)
                while (isRecording) {
                    val read = audioRecord?.read(buffer, 0, minBufferSize) ?: 0
                    if (read > 0) {
                        val volume = calculateVolume(buffer, read)
                        val normalized = (volume.coerceIn(0, 100).toDouble() / 100.0)
                            .coerceIn(0.0, 1.0)
                        channel.invokeMethod("onVolume", mapOf("volume" to normalized))
                    }
                }
            }.apply { start() }
        } catch (e: Exception) {
            Log.e(TAG, "启动录音失败: ${e.message}")
        }
    }

    private fun stopRecording() {
        isRecording = false
        try {
            recordingThread?.join(500)
        } catch (_: Exception) { }
        recordingThread = null
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        } catch (_: Exception) { }
    }

    private fun calculateVolume(buffer: ByteArray, readSize: Int): Int {
        var sumVolume = 0.0
        for (i in 0 until (readSize - 1) step 2) {
            val sample = ((buffer[i + 1].toInt() shl 8) or (buffer[i].toInt() and 0xFF)).toShort()
            sumVolume += kotlin.math.abs(sample.toDouble())
        }
        val rms = kotlin.math.sqrt(sumVolume / (readSize / 2))
        return (20.0 * kotlin.math.log10(1.0 + rms / 32768.0 * 100.0)).toInt().coerceIn(0, 100)
    }

    // ═══════════════════════════ 停止 ═══════════════════════════

    private fun handleStopListening(call: MethodCall, result: Result) {
        isListening = false
        stopRecording()
        channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        result.success(null)
    }

    private fun handleStopSpeaking(call: MethodCall, result: Result) {
        stopSpeakingInternal()
        result.success(null)
    }

    private fun stopSpeakingInternal() {
        isSpeaking = false
        mainHandler.removeCallbacksAndMessages(null)
    }

    // ═══════════════════════════ 销毁 ═══════════════════════════

    private fun handleDestroy(call: MethodCall, result: Result) {
        isListening = false
        isSpeaking = false
        stopRecording()
        mainHandler.removeCallbacksAndMessages(null)
        result.success(null)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
