package com.bilhealth.bodyintelligencelog

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class BILTextToSpeechBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, TextToSpeech.OnInitListener {
    private val methods = MethodChannel(messenger, "bil/tts")
    private val appContext = context.applicationContext
    private var engine: TextToSpeech? = null
    private var ready = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingAvailability = mutableListOf<MethodChannel.Result>()
    private val pendingSpeech = mutableMapOf<String, MethodChannel.Result>()
    private var utteranceCounter = 0L

    init {
        methods.setMethodCallHandler(this)
    }

    private fun ensureEngine() {
        if (engine == null) engine = TextToSpeech(appContext, this)
    }

    override fun onInit(status: Int) {
        ready = status == TextToSpeech.SUCCESS
        if (ready) {
            engine?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) = Unit

                override fun onDone(utteranceId: String?) {
                    utteranceId ?: return
                    mainHandler.post {
                        pendingSpeech.remove(utteranceId)?.success(null)
                    }
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    utteranceId ?: return
                    mainHandler.post {
                        pendingSpeech.remove(utteranceId)?.error("tts_failed", null, null)
                    }
                }

                override fun onError(utteranceId: String?, errorCode: Int) {
                    utteranceId ?: return
                    mainHandler.post {
                        pendingSpeech.remove(utteranceId)?.error(
                            "tts_failed",
                            errorCode.toString(),
                            null,
                        )
                    }
                }

                override fun onStop(utteranceId: String?, interrupted: Boolean) {
                    utteranceId ?: return
                    mainHandler.post {
                        pendingSpeech.remove(utteranceId)?.error("tts_stopped", null, null)
                    }
                }
            })
            val voiceNames = engine?.voices.orEmpty()
                .sortedBy { it.locale.toLanguageTag() + it.name }
                .joinToString(" | ") { "${it.locale.toLanguageTag()}:${it.name}" }
            Log.d("BILCoachTTS", "available voices=$voiceNames")
        }
        pendingAvailability.toList().forEach { it.success(ready) }
        pendingAvailability.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> {
                if (engine == null) {
                    pendingAvailability += result
                    ensureEngine()
                    return
                }
                result.success(ready)
            }
            "stop" -> {
                engine?.stop()
                pendingSpeech.values.toList().forEach {
                    it.error("tts_stopped", null, null)
                }
                pendingSpeech.clear()
                result.success(null)
            }
            "speak" -> {
                ensureEngine()
                val text = call.argument<String>("text")?.trim().orEmpty()
                if (!ready || text.isEmpty()) {
                    result.error("tts_unavailable", null, null)
                    return
                }
                val requested = call.argument<String>("locale")?.trim().orEmpty()
                val locale = Locale.forLanguageTag(requested.ifEmpty { "en" })
                val activeEngine = engine
                if (activeEngine == null) {
                    result.error("tts_unavailable", null, null)
                    return
                }
                val languageResult = activeEngine.setLanguage(locale)
                if (languageResult == TextToSpeech.LANG_MISSING_DATA ||
                    languageResult == TextToSpeech.LANG_NOT_SUPPORTED
                ) {
                    result.error("tts_locale_unavailable", requested, null)
                    return
                }
                val requestedGender = call.argument<String>("voiceGender")?.lowercase().orEmpty()
                val requestedTag = locale.toLanguageTag().lowercase()
                val requiresExactVoice = requestedTag.contains("-")
                val localeVoices = activeEngine.voices.orEmpty().filter { voice ->
                    val voiceTag = voice.locale.toLanguageTag().lowercase()
                    voice.locale.language.equals(locale.language, ignoreCase = true) &&
                        (!requiresExactVoice || voiceTag == requestedTag ||
                            (requestedTag == "zh-hans" && voiceTag == "zh-cn") ||
                            (requestedTag == "zh-hant" && voiceTag == "zh-tw"))
                }
                val selectedVoice = localeVoices.firstOrNull { voice ->
                    val name = voice.name.lowercase()
                    val descriptor = (sequenceOf(name) + voice.features.orEmpty().asSequence())
                        .joinToString(" ")
                        .lowercase()
                    when (requestedGender) {
                        "female" -> descriptor.contains("female") ||
                            descriptor.contains("woman") || descriptor.contains("gender=f")
                        "male" -> !descriptor.contains("female") &&
                            (Regex("(^|[-_# =])male($|[-_# ])").containsMatchIn(descriptor) ||
                                descriptor.contains("man") || descriptor.contains("gender=m"))
                        else -> false
                    }
                }
                if (selectedVoice != null) activeEngine.voice = selectedVoice
                Log.d(
                    "BILCoachTTS",
                    "requested=$requestedTag gender=$requestedGender selected=${selectedVoice?.name}",
                )
                activeEngine.setSpeechRate(0.92f)
                activeEngine.setPitch(
                    when (requestedGender) {
                        "female" -> 1.08f
                        "male" -> 0.72f
                        else -> 1.0f
                    },
                )
                val utteranceId = "bil-coach-${++utteranceCounter}"
                pendingSpeech[utteranceId] = result
                val code = activeEngine.speak(
                    text,
                    TextToSpeech.QUEUE_FLUSH,
                    null,
                    utteranceId,
                )
                if (code != TextToSpeech.SUCCESS) {
                    pendingSpeech.remove(utteranceId)
                    result.error("tts_failed", null, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        engine?.stop()
        engine?.shutdown()
        engine = null
        pendingSpeech.values.toList().forEach {
            it.error("tts_stopped", null, null)
        }
        pendingSpeech.clear()
        pendingAvailability.clear()
        methods.setMethodCallHandler(null)
    }
}
