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
    private var detectedLanguageTag: String? = null
    private var sessionActive = false

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
                finishPendingListen("speech_start_cancelled")
                // Mark the session inactive before asking the platform service
                // to stop. Otherwise a quick second tap sees a stale busy
                // flag while the recognizer is finishing its callback.
                val wasActive = sessionActive
                sessionActive = false
                if (wasActive) {
                    try {
                        recognizer?.stopListening()
                    } catch (_: Exception) {
                        resetRecognizer()
                    }
                }
                emitStatus(false)
                result.success(null)
            }
            "cancel" -> {
                finishPendingListen("speech_start_cancelled")
                if (sessionActive) {
                    try {
                        recognizer?.cancel()
                    } catch (_: Exception) {
                        resetRecognizer()
                    }
                }
                sessionActive = false
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
        if (sessionActive) {
            result.error("speech_recognizer_busy", null, null)
            return
        }
        detectedLanguageTag = null
        if (recognizer == null) {
            try {
                recognizer = SpeechRecognizer.createSpeechRecognizer(activity).also {
                    it.setRecognitionListener(this)
                }
            } catch (error: Exception) {
                result.error("speech_unavailable", error.message, null)
                emitError("speech_unavailable")
                return
            }
        }
        val activeRecognizer = recognizer
        if (activeRecognizer == null) {
            result.error("speech_unavailable", null, null)
            emitError("speech_unavailable")
            return
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, call.argument<Boolean>("partialResults") ?: true)
            val pauseForMs = (call.argument<Number>("pauseForMs")?.toInt() ?: 3_500)
                .coerceIn(500, 10_000)
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                pauseForMs,
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                pauseForMs,
            )
            // Some OEM recognizers interpret a missing minimum as an
            // immediate end-of-speech when the microphone route is still
            // warming up. Keep a short floor without delaying normal turns.
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
                pauseForMs.coerceAtLeast(2_500),
            )
            val autoDetectLanguage = call.argument<Boolean>("autoDetectLanguage") ?: false
            val allowedLocaleIds = call.argument<List<String>>("allowedLocaleIds")
                ?.map { it.trim() }
                ?.filter { it.isNotEmpty() }
                ?.distinct()
                .orEmpty()
            // A bounded allow-list enables language switching on Android 14+.
            // When no allow-list is supplied (the AI Coach case), seed the
            // recognizer with the device locale instead of sending a null
            // locale to services that immediately return ERROR_CLIENT.
            val requestedLocale = call.argument<String>("localeId")
                ?.takeIf { it.isNotBlank() }
            val initialLocale = requestedLocale
                ?: if (
                    autoDetectLanguage && allowedLocaleIds.isEmpty()
                ) {
                    Locale.getDefault().toLanguageTag().takeIf {
                        it.isNotBlank() && it != "und"
                    }
                } else {
                    null
                }
            initialLocale?.let {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, it)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, it)
            }
            // Some Android recognition services advertise API 34 but do not
            // implement language-switch extras. Only send those extras when
            // the caller supplied an explicit bounded language allow-list;
            // otherwise use the device recognizer locale for compatibility.
            if (autoDetectLanguage &&
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
                allowedLocaleIds.isNotEmpty()) {
                // Language detection only reports a label. Language switching
                // changes the active recognition model and is what makes an
                // English sentence work while the BIL interface is Arabic.
                putExtra(
                    RecognizerIntent.EXTRA_ENABLE_LANGUAGE_SWITCH,
                    RecognizerIntent.LANGUAGE_SWITCH_QUICK_RESPONSE,
                )
                // Do not force offline recognition. Many global language
                // packs are available only through the installed recognition
                // service; forcing offline silently fell back to one language.
                if (allowedLocaleIds.isNotEmpty()) {
                    putStringArrayListExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_SWITCH_ALLOWED_LANGUAGES,
                        ArrayList(allowedLocaleIds),
                    )
                }
            }
        }
        sessionActive = true
        try {
            activeRecognizer.startListening(intent)
        } catch (error: Exception) {
            sessionActive = false
            emitStatus(false)
            emitError("speech_start_failed")
            result.error("speech_start_failed", error.message, null)
            return
        }
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

    override fun onLanguageDetection(results: Bundle) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        detectedLanguageTag = results
            .getString(SpeechRecognizer.DETECTED_LANGUAGE)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }

    override fun onError(error: Int) {
        sessionActive = false
        emitStatus(false)
        val code = when (error) {
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "speech_timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "speech_no_match"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "microphone_permission_denied"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "speech_recognizer_busy"
            SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "speech_offline_service_unavailable"
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "speech_language_not_supported"
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "speech_language_unavailable"
            else -> "recognizer_error_$error"
        }
        emitError(code)
        if (error == SpeechRecognizer.ERROR_CLIENT ||
            error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY) {
            // A few vendor recognizers remain wedged after these callbacks.
            // Recreate the service on the next deliberate tap rather than
            // making every later capture fail with the same immediate stop.
            val staleRecognizer = recognizer
            recognizer = null
            try {
                staleRecognizer?.cancel()
            } catch (_: Exception) {
                // The recognizer may already have torn down its binder.
            }
            try {
                staleRecognizer?.destroy()
            } catch (_: Exception) {
                // Releasing a failed vendor service is best effort.
            }
        }
    }

    override fun onResults(results: Bundle?) = emitResults(results, true)
    override fun onPartialResults(partialResults: Bundle?) = emitResults(partialResults, false)

    private fun emitResults(bundle: Bundle?, isFinal: Boolean) {
        val words = bundle
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            .orEmpty()
        eventSink?.success(
            mapOf(
                "type" to "result",
                "words" to words,
                "final" to isFinal,
                "localeId" to detectedLanguageTag,
            ),
        )
        if (isFinal) {
            sessionActive = false
            emitStatus(false)
            if (words.isBlank()) emitError("speech_no_match")
        }
    }

    private fun emitStatus(listening: Boolean) {
        eventSink?.success(mapOf("type" to "status", "listening" to listening))
    }

    private fun emitError(code: String) {
        eventSink?.success(mapOf("type" to "error", "code" to code))
    }

    private fun resetRecognizer() {
        val staleRecognizer = recognizer
        recognizer = null
        sessionActive = false
        try {
            staleRecognizer?.cancel()
        } catch (_: Exception) {
            // Ignore a service that has already disconnected.
        }
        try {
            staleRecognizer?.destroy()
        } catch (_: Exception) {
            // Ignore a service that has already disconnected.
        }
    }

    private fun finishPendingListen(errorCode: String) {
        val pending = pendingListen ?: return
        pendingListen = null
        pending.second.error(errorCode, null, null)
    }

    fun dispose() {
        finishPendingListen("speech_disposed")
        resetRecognizer()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
