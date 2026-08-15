package com.bilhealth.bodyintelligencelog

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Build
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class BILSpeechBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
    private val requestMicrophonePermission: () -> Unit,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, RecognitionListener {
    private val methods = MethodChannel(messenger, "bil/speech")
    private val events = EventChannel(messenger, "bil/speech/events")
    private var eventSink: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var pendingListen: Pair<MethodCall, MethodChannel.Result>? = null

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> result.success(SpeechRecognizer.isRecognitionAvailable(activity))
            "locales" -> result.success(
                Locale.getAvailableLocales()
                    .map { it.toLanguageTag() }
                    .filter { it.isNotBlank() }
                    .distinct(),
            )
            "listen" -> startOrRequestPermission(call, result)
            "stop" -> {
                recognizer?.stopListening()
                emitStatus(false)
                result.success(null)
            }
            "cancel" -> {
                recognizer?.cancel()
                emitStatus(false)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startOrRequestPermission(call: MethodCall, result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            result.error("speech_unavailable", null, null)
            return
        }
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            if (pendingListen != null) {
                result.error("speech_permission_request_in_progress", null, null)
                return
            }
            pendingListen = call to result
            requestMicrophonePermission()
            return
        }
        startListening(call, result)
    }

    fun onMicrophonePermissionResult(granted: Boolean) {
        val pending = pendingListen ?: return
        pendingListen = null
        if (granted) {
            startListening(pending.first, pending.second)
        } else {
            pending.second.error("microphone_permission_denied", null, null)
            emitError("microphone_permission_denied")
        }
    }

    private fun startListening(call: MethodCall, result: MethodChannel.Result) {
        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(activity).also {
            it.setRecognitionListener(this)
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, call.argument<Boolean>("partialResults") ?: true)
            val autoDetectLanguage = call.argument<Boolean>("autoDetectLanguage") ?: false
            val allowedLocaleIds = call.argument<List<String>>("allowedLocaleIds")
                ?.map { it.trim() }
                ?.filter { it.isNotEmpty() }
                ?.distinct()
                .orEmpty()
            call.argument<String>("localeId")?.takeIf { it.isNotBlank() }?.let {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, it)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, it)
            }
            if (autoDetectLanguage && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                putExtra(RecognizerIntent.EXTRA_ENABLE_LANGUAGE_DETECTION, true)
                putExtra(
                    RecognizerIntent.EXTRA_ENABLE_LANGUAGE_SWITCH,
                    RecognizerIntent.LANGUAGE_SWITCH_QUICK_RESPONSE,
                )
                if (allowedLocaleIds.isNotEmpty()) {
                    putStringArrayListExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_DETECTION_ALLOWED_LANGUAGES,
                        ArrayList(allowedLocaleIds),
                    )
                    putStringArrayListExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_SWITCH_ALLOWED_LANGUAGES,
                        ArrayList(allowedLocaleIds),
                    )
                }
            }
        }
        recognizer?.startListening(intent)
        emitStatus(true)
        result.success(null)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onReadyForSpeech(params: Bundle?) = emitStatus(true)
    override fun onBeginningOfSpeech() = Unit
    override fun onRmsChanged(rmsdB: Float) = Unit
    override fun onBufferReceived(buffer: ByteArray?) = Unit
    override fun onEndOfSpeech() = Unit
    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    override fun onError(error: Int) {
        emitStatus(false)
        val code = when (error) {
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "speech_timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "speech_no_match"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "microphone_permission_denied"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "speech_recognizer_busy"
            SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "speech_offline_service_unavailable"
            else -> "recognizer_error_$error"
        }
        emitError(code)
    }

    override fun onResults(results: Bundle?) = emitResults(results, true)
    override fun onPartialResults(partialResults: Bundle?) = emitResults(partialResults, false)

    private fun emitResults(bundle: Bundle?, isFinal: Boolean) {
        val words = bundle
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            .orEmpty()
        eventSink?.success(mapOf("type" to "result", "words" to words, "final" to isFinal))
        if (isFinal) emitStatus(false)
    }

    private fun emitStatus(listening: Boolean) {
        eventSink?.success(mapOf("type" to "status", "listening" to listening))
    }

    private fun emitError(code: String) {
        eventSink?.success(mapOf("type" to "error", "code" to code))
    }

    fun dispose() {
        pendingListen?.second?.error("speech_disposed", null, null)
        pendingListen = null
        recognizer?.destroy()
        recognizer = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
