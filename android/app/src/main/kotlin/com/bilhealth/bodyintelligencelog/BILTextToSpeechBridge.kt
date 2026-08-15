package com.bilhealth.bodyintelligencelog

import android.content.Context
import android.speech.tts.TextToSpeech
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
    private val pendingAvailability = mutableListOf<MethodChannel.Result>()

    init {
        methods.setMethodCallHandler(this)
    }

    private fun ensureEngine() {
        if (engine == null) engine = TextToSpeech(appContext, this)
    }

    override fun onInit(status: Int) {
        ready = status == TextToSpeech.SUCCESS
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
                activeEngine.setSpeechRate(0.94f)
                activeEngine.setPitch(1.0f)
                val code = activeEngine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "bil-coach")
                if (code == TextToSpeech.SUCCESS) result.success(null)
                else result.error("tts_failed", null, null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        engine?.stop()
        engine?.shutdown()
        engine = null
        pendingAvailability.clear()
        methods.setMethodCallHandler(null)
    }
}
