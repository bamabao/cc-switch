package com.bamaobao.bamabao

import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.nio.charset.Charset
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 爸妈宝 — 语音插件桥接
 *
 * 集成讯飞SDK：离线AIKit TTS + ESR + 在线SparkChain
 * Kotlin 2.x 空安全渐进式适配版
 */
class VoicePlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        private const val TAG = "VoicePlugin"
        // 离线能力ID
        private const val AISOUND_ABILITY = "ece9d3c90"   // 离线TTS
        private const val ESR_ABILITY = "e75f07b62"      // 离线命令词识别

        // 音频播放常量
        private const val AUDIOPLAYER_INIT = 0x0000
        private const val AUDIOPLAYER_START = 0x0001
        private const val AUDIOPLAYER_WRITE = 0x0002
        private const val AUDIOPLAYER_END = 0x0003
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_OUT_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        // 录音常量
        private const val BUFFER_SIZE = 1280
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val mainHandler = Handler(Looper.getMainLooper())

    // 离线SDK状态
    private var aisoundEngineInit = false
    private var esrEngineInit = false
    private var isLoadData = false

    // 录音
    private var audioRecord: AudioRecord? = null
    private val isRecording = AtomicBoolean(false)

    // 录音线程
    private var audioThread: Thread? = null
    private var audioHandler: Handler? = null

    // 音频播放线程
    private var audioTrack: AudioTrack? = null
    private var isPlaying = false
    private var playHandler: Handler? = null
    private var playThread: Thread? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.bamaobao/voice")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
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

    // ═══════ 初始化 ═══════
    private fun handleInit(call: MethodCall, result: Result) {
        try {
            // 初始化离线AIKit语音合成引擎（Mock版，待真实SDK接入）
            if (!aisoundEngineInit) {
                Log.d(TAG, "初始化离线TTS引擎（Mock）")
                aisoundEngineInit = true
            }
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "初始化异常: ${e.message}")
            result.success(false)
        }
    }

    // ═══════ 设置参数 ═══════
    private fun handleSetParams(call: MethodCall, result: Result) {
        result.success(null)
    }

    // ═══════ 在线语音识别（ASR） ═══════
    private fun handleStartListening(call: MethodCall, result: Result) {
        // Mock实现：模拟2秒后返回识别结果
        channel.invokeMethod("onStatus", mapOf("status" to "listening"))
        startRecording()

        mainHandler.postDelayed({
            val mockTexts = listOf("帮我看看今天的药", "打卡签到", "呼叫医生", "我的积分")
            val mockResult = mockTexts.random()
            channel.invokeMethod("onResult", mapOf("text" to mockResult))
            channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        }, 2000)

        result.success("recording_started")
    }

    // ═══════ 离线命令词识别 ═══════
    private fun handleStartOfflineListening(call: MethodCall, result: Result) {
        channel.invokeMethod("onStatus", mapOf("status" to "listening"))

        mainHandler.postDelayed({
            channel.invokeMethod("onResult", mapOf("text" to "帮我看看今天的药"))
            channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        }, 1500)

        result.success("offline_recording_started")
    }

    // ═══════ TTS 播报 ═══════
    private fun handleSpeak(call: MethodCall, result: Result) {
        val text = call.argument<String>("text") ?: ""

        if (text.isEmpty()) {
            result.error("EMPTY_TEXT", "播报文本为空", null)
            return
        }

        // Mock：按字符数模拟播报时长
        mockSpeak(text)
        result.success(null)
    }

    private fun mockSpeak(text: String) {
        val delayMs = text.length * 100L
        channel.invokeMethod("onStatus", mapOf("status" to "speaking"))
        mainHandler.postDelayed({
            channel.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
            channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        }, delayMs)
    }

    // ═══════ 停止 ═══════
    private fun handleStopListening(call: MethodCall, result: Result) {
        stopRecording()
        channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        result.success(null)
    }

    private fun handleStopSpeaking(call: MethodCall, result: Result) {
        stopPlayback()
        result.success(null)
    }

    // ═══════ 销毁 ═══════
    private fun handleDestroy(call: MethodCall, result: Result) {
        stopRecording()
        stopPlayback()
        aisoundEngineInit = false
        esrEngineInit = false
        result.success(null)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ═══════ 录音实现 ═══════
    private fun startRecording() {
        if (isRecording.get()) return
        if (audioRecord == null) {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                16000,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                BUFFER_SIZE
            )
        }
        try {
            audioRecord?.startRecording()
        } catch (e: Exception) {
            Log.e(TAG, "启动录音失败: ${e.message}")
            return
        }
        isRecording.set(true)

        Thread {
            while (isRecording.get()) {
                val buffer = ByteArray(BUFFER_SIZE)
                val read = audioRecord?.read(buffer, 0, BUFFER_SIZE) ?: 0
                if (read > 0) {
                    val volume = calculateVolume(buffer)
                    channel.invokeMethod("onVolume", mapOf("volume" to volume / 100.0))
                }
            }
        }.start()
    }

    private fun stopRecording() {
        isRecording.set(false)
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        } catch (e: Exception) {
            Log.e(TAG, "停止录音异常: ${e.message}")
        }
    }

    private fun calculateVolume(buffer: ByteArray): Int {
        var sumVolume = 0.0
        for (i in buffer.indices step 2) {
            val v1 = buffer[i].toInt() and 0xFF
            val v2 = buffer[i + 1].toInt() and 0xFF
            var temp = v1 + (v2 shl 8)
            if (temp >= 0x8000) temp = 0xFFFF - temp
            sumVolume += Math.abs(temp)
        }
        val avgVolume = sumVolume / buffer.size / 2
        return (Math.log10(1 + avgVolume) * 10).toInt()
    }

    // ═══════ 音频播放器（Mock） ═══════
    private fun stopPlayback() {
        playHandler?.removeCallbacksAndMessages(null)
        try {
            audioTrack?.stop()
        } catch (e: Exception) { /* ignore */ }
        try {
            audioTrack?.release()
            audioTrack = null
        } catch (e: Exception) { /* ignore */ }
        isPlaying = false
    }
}
