package com.bamaobao.bamabao

import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import com.iflytek.aikit.core.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 爸妈宝 — 离线语音插件桥接 (AIKit SDK)
 *
 * 离线合成（Aisound ece9d3c90）: 轻量级离线TTS
 * 离线命令词（CNENESR e75f07b62）: 本地FSA命令词识别
 *
 * 资源文件: assets/aikit/resource/
 * APPID:    2d77802d (AndroidManifest meta-data)
 *
 * 使用流程:
 *   init → (TTS: registerListener → start → write → onResult播放音频)
 *        → (ESR: registerListener → engineInit → loadData → specifyDataSet → start → write+read → onResult回调)
 */
class VoicePlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        private const val TAG = "VoicePlugin"
        private const val SAMPLE_RATE = 16000
        private const val BUFFER_SIZE = 1280

        // ═══ 能力ID — AIKit SDK 用此标识区分引擎实例 ═══
        private const val ABILITY_TTS = "ece9d3c90"    // Aisound 离线TTS
        private const val ABILITY_ESR = "e75f07b62"    // CNENESR 离线命令词

        private const val TTS_VCN = "xiaoyan"          // 默认发音人

        private const val ASSETS_PREFIX = "aikit/resource"
    }

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private val mainHandler = Handler(Looper.getMainLooper())

    // ─── SDK 初始化状态 ───
    private var sdkInitialized = false
    private var esrEngineInitialized = false

    // ─── TTS ───
    private var ttsHandle: AiHandle? = null
    private var audioTrack: AudioTrack? = null

    // ─── ESR ───
    private var esrHandle: AiHandle? = null
    private var esrPendingResult: Result? = null
    private var fsaLoaded = false
    private var fsaIndex = 0
    private val esrRunning = AtomicBoolean(false)
    private var esrAudioRecord: AudioRecord? = null
    private val esrRecording = AtomicBoolean(false)

    // ═══════════════════════════════════════════════════════
    //              Flutter Plugin 生命周期
    // ═══════════════════════════════════════════════════════

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.bamaobao/voice")
        channel.setMethodCallHandler(this)
        appContext = binding.applicationContext
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        destroyInternal()
    }

    // ═══════════════════════════════════════════════════════
    //              MethodChannel 入口
    // ═══════════════════════════════════════════════════════

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "init" -> handleInit(result)
            "setParams" -> result.success(null)
            "startListening" -> handleStartListening(result)
            "startOfflineListening" -> handleStartOfflineListening(result)
            "speak" -> handleSpeak(call, result)
            "stopListening" -> handleStopListening(result)
            "stopSpeaking" -> handleStopSpeaking(result)
            "destroy" -> {
                destroyInternal()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ═══════════════════════════════════════════════════════
    //              1. SDK 初始化
    // ═══════════════════════════════════════════════════════

    private fun handleInit(result: Result) {
        if (sdkInitialized) {
            result.success(true)
            return
        }

        try {
            // 1. 创建工作目录
            val workDir = File(appContext.filesDir, "aikit")
            if (!workDir.exists()) workDir.mkdirs()

            // 2. 复制模型/资源文件到 workDir
            extractAssetsToWorkDir(workDir)

            // 3. 注册能力监听 (必须在 init 或者 start 之前注册)
            AiHelper.getInst().registerListener(ABILITY_TTS, ttsListener)
            AiHelper.getInst().registerListener(ABILITY_ESR, esrListener)

            // 4. 尝试加载 APIKey/APISecret（从 strings.xml）
            val appId = getResString("appId", "2d77802d")
            val apiKey = getResString("apiKey", "")
            val apiSecret = getResString("apiSecret", "")

            if (apiKey.isBlank() || apiKey == "REPLACE_WITH_YOUR_API_KEY") {
                Log.w(TAG, "⚠️ APIKey 未配置！请从讯飞控制台获取并写入 res/values/strings.xml")
                Log.w(TAG, "   登录 https://console.xfyun.cn → 我的应用 → APPID: $appId")
            }

            // 5. 初始化 SDK 参数
            val paramsBuilder = BaseLibrary.Params.builder()
                .appId(appId)
                .workDir(workDir.absolutePath)

            if (apiKey.isNotBlank() && apiSecret.isNotBlank()) {
                paramsBuilder.apiKey(apiKey)
                paramsBuilder.apiSecret(apiSecret)
            }

            val params = paramsBuilder.build()
            AiHelper.getInst().initEntry(appContext, params)
            Log.i(TAG, "AIKit SDK initEntry 完成")

            sdkInitialized = true

            // 6. 异步初始化 ESR 引擎（避免主线程阻塞导致ANR）
            Thread {
                try {
                    initEsrEngine(workDir)
                } catch (e: Exception) {
                    Log.w(TAG, "ESR异步初始化异常（非致命）: ${e.message}")
                }
            }.start()

            Log.i(TAG, "离线语音引擎初始化成功")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "AIKit 初始化异常: ${e.message}")
            result.success(false)
        }
    }

    private fun getResString(name: String, defaultVal: String): String {
        return try {
            val resId = appContext.resources.getIdentifier(name, "string", appContext.packageName)
            if (resId != 0) appContext.getString(resId) else defaultVal
        } catch (_: Exception) { defaultVal }
    }

    private fun extractAssetsToWorkDir(workDir: File) {
        // 模型文件列表
        val modelFiles = listOf(
            "aisound/ece9d3c90_ivTTS_CE+PE_xiaoyan.16K.irf_1.0.0",
            "aisound/ece9d3c90_ivTTS_CE+PE_xiaofeng.16K.irf_1.0.0",
            "aisound/ivTTS_CE+PE_front.16K.irf_1.0.0",
            "CNENESR/e75f07b62_WFST_CN.bin_1.0.0.0",
            "CNENESR/e75f07b62_MLP_XN_CN.bin_1.0.0.0",
            "CNENESR/e75f07b62_MLP_VAD_CN.bin_1.0.0.0"
        )
        for (relPath in modelFiles) {
            copyAsset("$ASSETS_PREFIX/$relPath", File(workDir, relPath))
        }

        // 复制 FSA 命令词文件
        val fsaDir = File(workDir, "CNENESR/fsa")
        fsaDir.mkdirs()
        copyAsset("$ASSETS_PREFIX/CNENESR/fsa/cn_fsa.txt", File(fsaDir, "cn_fsa.txt"))
        copyAsset("$ASSETS_PREFIX/CNENESR/fsa/en_fsa.txt", File(fsaDir, "en_fsa.txt"))
    }

    private fun copyAsset(assetPath: String, outFile: File) {
        try {
            if (outFile.exists()) return
            outFile.parentFile?.mkdirs()
            appContext.assets.open(assetPath).use { input ->
                FileOutputStream(outFile).use { output -> input.copyTo(output) }
            }
            Log.d(TAG, "复制: $assetPath → ${outFile.name}")
        } catch (e: Exception) {
            Log.w(TAG, "跳过(不存在) $assetPath: ${e.message}")
        }
    }

    private fun initEsrEngine(workDir: File) {
        if (esrEngineInitialized) return
        try {
            val engineBuilder = AiRequest.builder()
            engineBuilder.param("decNetType", "fsa")
            engineBuilder.param("punishCoefficient", 0.0)
            engineBuilder.param("wfst_addType", 0) // 0=中文
            val ret = AiHelper.getInst().engineInit(ABILITY_ESR, engineBuilder.build())
            if (ret == 0) {
                esrEngineInitialized = true
                Log.i(TAG, "ESR engineInit 成功")
            } else {
                Log.w(TAG, "ESR engineInit 返回 $ret, 运行时按需重试")
            }
        } catch (e: Exception) {
            Log.w(TAG, "ESR engineInit 异常: ${e.message}")
        }
    }

    // ═══════════════════════════════════════════════════════
    //              2. TTS 离线合成 (Aisound)
    // ═══════════════════════════════════════════════════════

    private fun handleSpeak(call: MethodCall, result: Result) {
        val text = call.argument<String>("text") ?: ""
        if (text.isEmpty()) {
            result.error("EMPTY_TEXT", "播报文本为空", null)
            return
        }

        // 停止上一个 TTS
        stopTts()

        // 初始化 AudioTrack
        if (audioTrack == null) {
            val bufSize = AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            ) * 4
            audioTrack = AudioTrack(
                AudioManager.STREAM_MUSIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufSize,
                AudioTrack.MODE_STREAM
            )
        }
        audioTrack?.play()

        channel.invokeMethod("onStatus", mapOf("status" to "speaking"))

        runTts(text)
        result.success(null)
    }

    private fun runTts(text: String) {
        val paramBuilder = AiInput.builder()
        paramBuilder.param("vcn", TTS_VCN)
        paramBuilder.param("textEncoding", "UTF-8")
        paramBuilder.param("pitch", 50)
        paramBuilder.param("volume", 50)
        paramBuilder.param("speed", 50)

        val handle = AiHelper.getInst().start(ABILITY_TTS, paramBuilder.build(), null)
        if (handle.code != 0) {
            Log.e(TAG, "TTS start 失败: ${handle.code}")
            channel.invokeMethod("onStatus", mapOf("status" to "idle"))
            channel.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
            return
        }
        ttsHandle = handle

        val dataBuilder = AiRequest.builder()
        dataBuilder.payload(AiText.get("text").data(text).valid())
        val ret = AiHelper.getInst().write(dataBuilder.build(), handle)
        if (ret != 0) {
            Log.e(TAG, "TTS write 失败: $ret")
            AiHelper.getInst().end(handle)
            ttsHandle = null
            channel.invokeMethod("onStatus", mapOf("status" to "idle"))
            channel.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
        }
    }

    private val ttsListener = object : AiListener {
        override fun onResult(handleID: Int, list: List<AiResponse>?, usrContext: Any?) {
            if (list == null) return
            for (resp in list) {
                if (resp.key == "audio" && resp.value != null) {
                    try {
                        audioTrack?.write(resp.value, 0, resp.value.size)
                    } catch (e: Exception) {
                        Log.w(TAG, "AudioTrack.write 异常: ${e.message}")
                    }
                }
            }
        }

        override fun onEvent(handleID: Int, event: Int, eventData: List<AiResponse>?, usrContext: Any?) {
            if (event == AeeEvent.AEE_EVENT_END.value) {
                // 合成完成
                ttsHandle?.let { AiHelper.getInst().end(it) }
                ttsHandle = null
                mainHandler.post {
                    audioTrack?.stop()
                    audioTrack?.flush()
                    channel.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
                    channel.invokeMethod("onStatus", mapOf("status" to "idle"))
                }
            }
        }

        override fun onError(handleID: Int, err: Int, msg: String?, usrContext: Any?) {
            Log.e(TAG, "TTS 错误: err=$err, msg=$msg")
            ttsHandle?.let { AiHelper.getInst().end(it) }
            ttsHandle = null
            mainHandler.post {
                audioTrack?.stop()
                channel.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
                channel.invokeMethod("onStatus", mapOf("status" to "idle"))
            }
        }
    }

    private fun stopTts() {
        ttsHandle?.let {
            try { AiHelper.getInst().end(it) } catch (_: Exception) { }
            ttsHandle = null
        }
        audioTrack?.let {
            try {
                it.stop()
                it.flush()
            } catch (_: Exception) { }
        }
        mainHandler.removeCallbacksAndMessages(null)
    }

    // ═══════════════════════════════════════════════════════
    //         3. 离线命令词识别 (CNENESR)
    // ═══════════════════════════════════════════════════════

    private fun handleStartListening(result: Result) {
        // 暂降级为离线命令词（无在线MSC SDK）
        handleStartOfflineListening(result)
    }

    private fun handleStartOfflineListening(result: Result) {
        if (esrRunning.get()) {
            result.success("already_listening")
            return
        }

        esrPendingResult = result
        channel.invokeMethod("onStatus", mapOf("status" to "listening"))

        val workDir = File(appContext.filesDir, "aikit")
        val fsaPath = File(workDir, "CNENESR/fsa/cn_fsa.txt").absolutePath

        Thread {
            try {
                // 确保引擎已初始化（安全兜底）
                try {
                    initEsrEngine(workDir)
                } catch (e: Exception) {
                    Log.w(TAG, "ESR初始化重试异常: ${e.message}")
                }

                // 1. 加载 FSA 命令词 (仅首次)
                if (!fsaLoaded) {
                    val loadBuilder = AiRequest.builder()
                    loadBuilder.customText("FSA", fsaPath, fsaIndex)
                    val loadRet = AiHelper.getInst().loadData(ABILITY_ESR, loadBuilder.build())
                    if (loadRet != 0) {
                        Log.e(TAG, "FSA loadData 失败: $loadRet")
                        failEsr("")
                        return@Thread
                    }
                    fsaLoaded = true
                }

                // 2. 指定使用刚加载的 FSA 数据集
                val idx = intArrayOf(fsaIndex)
                val specRet = AiHelper.getInst().specifyDataSet(ABILITY_ESR, "FSA", idx)
                if (specRet != 0) {
                    Log.e(TAG, "specifyDataSet 失败: $specRet")
                    failEsr("")
                    return@Thread
                }

                // 3. start 会话
                val startBuilder = AiRequest.builder()
                startBuilder.param("languageType", 0)
                startBuilder.param("vadEndGap", 60)
                startBuilder.param("vadOn", true)
                startBuilder.param("beamThreshold", 20)
                startBuilder.param("hisGramThreshold", 3000)
                startBuilder.param("vadLinkOn", false)
                startBuilder.param("vadSpeechEnd", 80)
                startBuilder.param("vadResponsetime", 1000)
                startBuilder.param("postprocOn", false)

                val handle = AiHelper.getInst().start(ABILITY_ESR, startBuilder.build(), null)
                if (handle.code != 0) {
                    Log.e(TAG, "ESR start 失败: ${handle.code}")
                    failEsr("")
                    return@Thread
                }
                esrHandle = handle
                esrRunning.set(true)

                // 4. 创建 AudioRecord
                val minBuf = AudioRecord.getMinBufferSize(
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                ).coerceAtLeast(BUFFER_SIZE)

                esrAudioRecord = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    minBuf
                )
                esrAudioRecord?.startRecording()
                esrRecording.set(true)

                // 5. 先写 BEGIN 帧
                try {
                    writeEsrAudio(ByteArray(0), AiStatus.BEGIN)
                } catch (e: Exception) {
                    Log.w(TAG, "ESR BEGIN帧异常: ${e.message}")
                }

                // 6. 录音循环 → write → read
                val buf = ByteArray(minBuf)
                while (esrRecording.get() && esrRunning.get()) {
                    try {
                        val read = esrAudioRecord?.read(buf, 0, minBuf) ?: -1
                        if (read <= 0) continue

                        writeEsrAudio(buf.copyOf(read), AiStatus.CONTINUE)
                    } catch (e: Exception) {
                        Log.w(TAG, "ESR录音读取异常: ${e.message}")
                        break
                    }

                    // 音量上报
                    val vol = calculateVolume(buf, minBuf.coerceAtMost(1280))
                    mainHandler.post {
                        channel.invokeMethod(
                            "onVolume", mapOf("volume" to (vol / 100.0).coerceIn(0.0, 1.0))
                        )
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "ESR 异常: ${e.message}")
                failEsr("")
            }
        }.apply { start() }
    }

    private fun writeEsrAudio(data: ByteArray, status: AiStatus) {
        val handle = esrHandle ?: return
        val builder = AiRequest.builder()
        builder.payload(AiAudio.get("audio").data(data).status(status).valid())
        val ret = AiHelper.getInst().write(builder.build(), handle)
        if (ret == 0) {
            // write 成功后必须调 read 触发引擎解码
            AiHelper.getInst().read(ABILITY_ESR, handle)
        } else {
            Log.w(TAG, "ESR write 返回: $ret")
        }
    }

    private val esrListener = object : AiListener {
        override fun onResult(handleID: Int, list: List<AiResponse>?, usrContext: Any?) {
            if (list == null) return

            var resultText = ""
            for (resp in list) {
                if (resp.value == null) continue
                val key = resp.key
                try {
                    val text = String(resp.value, Charsets.UTF_8)
                    Log.d(TAG, "ESR [$key]: $text")

                    if (key.contains("pgs") || key.contains("plain")) {
                        resultText = text
                        mainHandler.post {
                            channel.invokeMethod(
                                "onResult", mapOf("text" to text, "isFinal" to false)
                            )
                        }
                    }
                } catch (_: Exception) { }
            }

            // status == 2 => 最终结果
            if (list.isNotEmpty() && list[0].status == 2) {
                mainHandler.post {
                    stopEsrInternal()
                    if (resultText.isNotBlank()) {
                        channel.invokeMethod(
                            "onResult", mapOf("text" to resultText, "isFinal" to true)
                        )
                    }
                    esrPendingResult?.success(resultText)
                    esrPendingResult = null
                    esrRunning.set(false)
                    channel.invokeMethod("onStatus", mapOf("status" to "idle"))
                }
            }
        }

        override fun onEvent(handleID: Int, event: Int, eventData: List<AiResponse>?, usrContext: Any?) {
            Log.d(TAG, "ESR event: $event")
        }

        override fun onError(handleID: Int, err: Int, msg: String?, usrContext: Any?) {
            Log.e(TAG, "ESR 错误: err=$err, msg=$msg")
            failEsr("")
        }
    }

    private fun failEsr(fallbackText: String) {
        mainHandler.post {
            stopEsrInternal()
            esrPendingResult?.success(fallbackText)
            esrPendingResult = null
            esrRunning.set(false)
            channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        }
    }

    private fun stopEsrInternal() {
        esrRecording.set(false)
        esrRunning.set(false)

        // 发送 END 帧
        esrHandle?.let { handle ->
            try {
                val endBuilder = AiRequest.builder()
                endBuilder.payload(AiAudio.get("audio").data(ByteArray(0)).status(AiStatus.END).valid())
                AiHelper.getInst().write(endBuilder.build(), handle)
                AiHelper.getInst().end(handle)
            } catch (_: Exception) { }
            esrHandle = null
        }

        // 释放录音
        esrAudioRecord?.let {
            try {
                it.stop()
                it.release()
            } catch (_: Exception) { }
            esrAudioRecord = null
        }
    }

    // ═══════════════════════════════════════════════════════
    //              4. 停止操作
    // ═══════════════════════════════════════════════════════

    private fun handleStopListening(result: Result) {
        stopEsrInternal()
        result.success(null)
    }

    private fun handleStopSpeaking(result: Result) {
        stopTts()
        mainHandler.post {
            channel.invokeMethod("onSpeakCompleted", emptyMap<String, Any>())
            channel.invokeMethod("onStatus", mapOf("status" to "idle"))
        }
        result.success(null)
    }

    // ═══════════════════════════════════════════════════════
    //              5. 工具
    // ═══════════════════════════════════════════════════════

    private fun calculateVolume(buffer: ByteArray, readSize: Int): Int {
        if (readSize < 2) return 0
        var sum = 0.0
        for (i in 0 until (readSize - 1) step 2) {
            val sample = ((buffer[i + 1].toInt() shl 8) or (buffer[i].toInt() and 0xFF)).toShort()
            sum += kotlin.math.abs(sample.toDouble())
        }
        val rms = kotlin.math.sqrt(sum / (readSize / 2))
        return (20.0 * kotlin.math.log10(1.0 + rms / 32768.0 * 100.0)).toInt().coerceIn(0, 100)
    }

    // ═══════════════════════════════════════════════════════
    //              6. 销毁
    // ═══════════════════════════════════════════════════════

    private fun destroyInternal() {
        stopTts()
        stopEsrInternal()
        try {
            AiHelper.getInst().engineUnInit(ABILITY_TTS)
            AiHelper.getInst().engineUnInit(ABILITY_ESR)
        } catch (_: Exception) { }
        audioTrack?.release()
        audioTrack = null
        sdkInitialized = false
        esrEngineInitialized = false
        fsaLoaded = false
    }
}
