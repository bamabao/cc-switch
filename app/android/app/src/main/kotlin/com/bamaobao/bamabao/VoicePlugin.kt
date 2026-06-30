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
import com.iflytek.aikit.core.*
import com.iflytek.sparkchain.core.tts.OnlineTTS
import com.iflytek.sparkchain.core.tts.TTS
import com.iflytek.sparkchain.core.tts.TTSCallbacks
import java.util.concurrent.atomic.AtomicBoolean
import java.util.Arrays

/**
 * 爸妈宝 — 语音插件桥接
 *
 * 集成两套讯飞SDK：
 * - 离线AIKit：Aisound(TTS) + ESR(命令词识别)
 * - 在线SparkChain：OnlineTTS + OnlineASR
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
    private val handler = Handler(Looper.getMainLooper())

    // 离线SDK状态
    private var aisoundEngineInit = false
    private var esrEngineInit = false
    private var isLoadData = false
    private var aiHandle: AiHandle? = null

    // 在线SDK
    private var mOnlineTTS: OnlineTTS? = null

    // 录音
    private var audioRecord: AudioRecord? = null
    private val isRecording = AtomicBoolean(false)
    private val isEnd = AtomicBoolean(true)

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
            // 初始化离线AIKit语音合成引擎
            if (!aisoundEngineInit) {
                AiHelper.getInst().registerListener(AISOUND_ABILITY, aisoundListener)
                val engineBuilder = AiRequest.builder()
                engineBuilder.param("vcn", "xiaoyan")
                engineBuilder.param("sampleRate", 16000)
                val ret = AiHelper.getInst().engineInit(AISOUND_ABILITY, engineBuilder.build())
                if (ret != 0) {
                    Log.e(TAG, "离线TTS引擎初始化失败: $ret")
                    result.success(false)
                    return
                }
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
        // 参数当前由Flutter端控制，暂不处理
        result.success(null)
    }

    // ═══════ 在线语音识别（ASR） ═══════
    private fun handleStartListening(call: MethodCall, result: Result) {
        // 在线ASR通过讯飞提供的RTASR能力实现，需要网络
        // 初始化录音线程
        startAudioThread()

        // 初始化离线ESR引擎用于录音式命令词识别
        if (!esrEngineInit) {
            // ESR需要FSA文件，先返回mock用于演示，实际集成时替换
            initEsrEngine()
        }

        // 启动录音并发送到在线ASR（先返回结果给Flutter端）
        channel.invokeMethod("onStatus", mapOf("status" to "listening"))
        startRecording()

        result.success("recording_started")
    }

    // ═══════ 离线命令词识别 ═══════
    private fun handleStartOfflineListening(call: MethodCall, result: Result) {
        startAudioThread()
        if (!esrEngineInit) {
            initEsrEngine()
        }
        channel.invokeMethod("onStatus", mapOf("status" to "listening"))
        // 离线模式使用ESR
        result.success("offline_recording_started")
    }

    // ═══════ TTS 播报 ═══════
    private fun handleSpeak(call: MethodCall, result: Result) {
        val text = call.argument<String>("text") ?: ""

        if (text.isEmpty()) {
            result.error("EMPTY_TEXT", "播报文本为空", null)
            return
        }

        // 优先使用离线TTS，如失败则回退到在线TTS
        if (aisoundEngineInit) {
            speakOffline(text)
        } else {
            speakOnline(text)
        }

        result.success(null)
    }

    // ═══════ 停止 ═══════
    private fun handleStopListening(call: MethodCall, result: Result) {
        stopRecording()
        channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        result.success(null)
    }

    private fun handleStopSpeaking(call: MethodCall, result: Result) {
        stopPlayback()
        mOnlineTTS = null
        result.success(null)
    }

    // ═══════ 销毁 ═══════
    private fun handleDestroy(call: MethodCall, result: Result) {
        stopRecording()
        stopPlayback()

        if (aisoundEngineInit) {
            AiHelper.getInst().engineUnInit(AISOUND_ABILITY)
            aisoundEngineInit = false
        }
        if (esrEngineInit) {
            if (isLoadData) {
                AiHelper.getInst().unLoadData(ESR_ABILITY, "FSA", 0)
                isLoadData = false
            }
            AiHelper.getInst().engineUnInit(ESR_ABILITY)
            esrEngineInit = false
        }

        aiHandle = null
        result.success(null)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ═══════ 离线TTS实现 ═══════
    private fun speakOffline(text: String) {
        // 初始化音频播放器
        initAudioPlayer()

        val paramBuilder = AiInput.builder()
        paramBuilder.param("vcn", "xiaoyan")
        paramBuilder.param("textEncoding", "UTF-8")
        paramBuilder.param("pitch", 50)
        paramBuilder.param("volume", 80)
        paramBuilder.param("speed", 50)

        aiHandle = AiHelper.getInst().start(AISOUND_ABILITY, paramBuilder.build(), null)
        if (aiHandle?.code != 0) {
            Log.e(TAG, "离线TTS start失败: ${aiHandle?.code}")
            // 回退到在线TTS
            speakOnline(text)
            return
        }

        val dataBuilder = AiRequest.builder()
        val input = AiText.get("text").data(text).valid()
        dataBuilder.payload(input)

        val ret = AiHelper.getInst().write(dataBuilder.build(), aiHandle)
        if (ret != 0) {
            Log.e(TAG, "离线TTS write失败: $ret")
            speakOnline(text)
        }
    }

    private fun speakOnline(text: String) {
        mOnlineTTS = OnlineTTS("xiaoyan")
        mOnlineTTS?.speed(50)
        mOnlineTTS?.pitch(50)
        mOnlineTTS?.volume(80)
        mOnlineTTS?.bgs(0)
        mOnlineTTS?.registerCallbacks(object : TTSCallbacks() {
            override fun onResult(result: TTS.TTSResult?, o: Any?) {
                if (result != null) {
                    val audio = result.data
                    if (audio != null && audio.isNotEmpty()) {
                        val bundle = Bundle()
                        bundle.putByteArray("audio", audio)
                        val msg = playHandler?.obtainMessage()
                        msg?.what = AUDIOPLAYER_WRITE
                        msg?.obj = bundle
                        playHandler?.sendMessage(msg)
                    }
                    if (result.status == 2) {
                        playHandler?.sendEmptyMessage(AUDIOPLAYER_END)
                    }
                }
            }

            override fun onError(error: TTS.TTSError?, o: Any?) {
                Log.e(TAG, "在线TTS错误: code=${error?.code}, msg=${error?.errMsg}")
                channel.invokeMethod("onError", mapOf(
                    "code" to (error?.code ?: -1),
                    "message" to (error?.errMsg ?: "在线TTS失败")
                ))
            }
        })
        mOnlineTTS?.aRun(text)
    }

    // ═══════ 离线AIKit结果监听 ═══════
    private val aisoundListener = object : AiListener {
        override fun onResult(handleID: Int, list: List<AiResponse>?, usrContext: Any?) {
            if (list != null) {
                for (resp in list) {
                    val bytes = resp.value ?: continue
                    if (resp.key == "audio") {
                        val bundle = Bundle()
                        bundle.putByteArray("audio", bytes)
                        val msg = playHandler?.obtainMessage()
                        msg?.what = AUDIOPLAYER_WRITE
                        msg?.obj = bundle
                        playHandler?.sendMessage(msg)
                    }
                }
            }
        }

        override fun onEvent(handleID: Int, event: Int, eventData: List<AiResponse>?, usrContext: Any?) {
            if (event == AeeEvent.AEE_EVENT_END.value) {
                aiHandle?.let { AiHelper.getInst().end(it) }
                playHandler?.sendEmptyMessage(AUDIOPLAYER_END)
            }
        }

        override fun onError(handleID: Int, err: Int, msg: String?, usrContext: Any?) {
            Log.e(TAG, "离线TTS错误: code=$err, msg=$msg")
            channel.invokeMethod("onError", mapOf(
                "code" to err,
                "message" to (msg ?: "离线TTS失败")
            ))
        }
    }

    // ═══════ ESR引擎初始化 ═══════
    private fun initEsrEngine() {
        AiHelper.getInst().registerListener(ESR_ABILITY, esrListener)
        val engineBuilder = AiRequest.builder()
        engineBuilder.param("decNetType", "fsa")
        engineBuilder.param("punishCoefficient", 0.0)
        engineBuilder.param("wfst_addType", 0) // 0中文
        val ret = AiHelper.getInst().engineInit(ESR_ABILITY, engineBuilder.build())
        if (ret == 0) {
            esrEngineInit = true
            Log.d(TAG, "ESR引擎初始化成功")
        } else {
            Log.e(TAG, "ESR引擎初始化失败: $ret")
        }
    }

    private val esrListener = object : AiListener {
        override fun onResult(handleID: Int, outputData: List<AiResponse>?, usrContext: Any?) {
            if (outputData != null) {
                for (resp in outputData) {
                    try {
                        val result = String(resp.value ?: continue, "GBK")
                        if (resp.key.contains("plain")) {
                            Log.d(TAG, "ESR结果(plain): $result")
                            channel.invokeMethod("onResult", mapOf("text" to result))
                        } else if (resp.key.contains("pgs")) {
                            Log.d(TAG, "ESR结果(pgs): $result")
                            channel.invokeMethod("onResult", mapOf("text" to result))
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "ESR结果解析错误: ${e.message}")
                    }
                }
            }
        }

        override fun onEvent(handleID: Int, event: Int, eventData: List<AiResponse>?, usrContext: Any?) {}
        override fun onError(handleID: Int, err: Int, msg: String?, usrContext: Any?) {
            Log.e(TAG, "ESR错误: code=$err, msg=$msg")
            channel.invokeMethod("onError", mapOf(
                "code" to err,
                "message" to (msg ?: "离线识别失败")
            ))
        }
    }

    // ═══════ 录音实现 ═══════
    private fun startAudioThread() {
        if (audioThread == null || !audioThread!!.isAlive) {
            audioThread = Thread {
                Looper.prepare()
                audioHandler = Handler(Looper.myLooper()) { true }
                Looper.loop()
            }
            audioThread?.start()
        }
    }

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
        audioRecord?.startRecording()
        isRecording.set(true)

        Thread {
            while (isRecording.get()) {
                val data = ByteArray(BUFFER_SIZE)
                val read = audioRecord?.read(data, 0, BUFFER_SIZE) ?: 0
                if (read > 0) {
                    // 计算音量并回调
                    val volume = calculateVolume(data)
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

    // ═══════ 音频播放器 ═══════
    private fun initAudioPlayer() {
        if (playThread == null || !playThread!!.isAlive) {
            playThread = Thread {
                Looper.prepare()
                playHandler = Handler(Looper.myLooper()) { msg ->
                    when (msg.what) {
                        AUDIOPLAYER_INIT -> {
                            val minBuf = AudioTrack.getMinBufferSize(
                                SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT
                            )
                            audioTrack = AudioTrack(
                                AudioManager.STREAM_MUSIC, SAMPLE_RATE,
                                CHANNEL_CONFIG, AUDIO_FORMAT, minBuf,
                                AudioTrack.MODE_STREAM
                            )
                            playHandler?.sendEmptyMessage(AUDIOPLAYER_START)
                        }
                        AUDIOPLAYER_START -> {
                            audioTrack?.let {
                                isPlaying = true
                                it.play()
                            }
                        }
                        AUDIOPLAYER_WRITE -> {
                            val bundle = msg.obj as? Bundle
                            val audioData = bundle?.getByteArray("audio")
                            if (audioTrack != null && !audioData.isNullOrEmpty()) {
                                audioTrack?.write(audioData, 0, audioData.size)
                            }
                        }
                        AUDIOPLAYER_END -> {
                            try {
                                if (audioTrack != null && isPlaying) {
                                    audioTrack?.stop()
                                    isPlaying = false
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "播放停止异常: ${e.message}")
                            }
                            channel.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
                        }
                    }
                    true
                }
                Looper.loop()
            }
            playThread?.start()
        }
        // 初始化播放器
        playHandler?.sendEmptyMessage(AUDIOPLAYER_INIT)
    }

    private fun stopPlayback() {
        playHandler?.removeCallbacksAndMessages(null)
        playHandler?.sendEmptyMessage(AUDIOPLAYER_END)
        try {
            audioTrack?.release()
            audioTrack = null
        } catch (e: Exception) { /* ignore */ }
    }
}
