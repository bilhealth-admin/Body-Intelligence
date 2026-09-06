package com.bilhealth.bodyintelligencelog

import android.content.Context
import android.media.MediaPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Plays the two local microphone affordance sounds. */
class BILMicSoundBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val methods = MethodChannel(messenger, "bil/mic_sound")
    private val appContext = context.applicationContext
    private var player: MediaPlayer? = null
    private var playbackResult: MethodChannel.Result? = null

    init {
        methods.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val resource = when (call.method) {
            "playOpen" -> com.bilhealth.bodyintelligencelog.R.raw.bil_mic_open_vibration
            "playEnd" -> com.bilhealth.bodyintelligencelog.R.raw.bil_mic_end_vibration
            else -> null
        }
        if (resource == null) {
            result.notImplemented()
            return
        }
        try {
            player?.release()
            finishPendingPlayback()
            player = MediaPlayer.create(appContext, resource)
            val active = player
            if (active == null) {
                result.error("mic_sound_unavailable", null, null)
                return
            }
            active.setVolume(0.55f, 0.55f)
            playbackResult = result
            active.setOnCompletionListener { completed ->
                if (player === completed) player = null
                completed.release()
                finishPendingPlayback()
            }
            active.setOnErrorListener { failed, _, _ ->
                if (player === failed) player = null
                failed.release()
                finishPendingPlayback("mic_sound_playback_failed", null)
                true
            }
            active.start()
        } catch (error: Exception) {
            player?.release()
            player = null
            if (playbackResult === result) {
                finishPendingPlayback("mic_sound_failed", error.message)
            } else {
                result.error("mic_sound_failed", error.message, null)
            }
        }
    }

    /**
     * The Dart caller awaits this reply before starting speech recognition.
     * Replying from MediaPlayer completion keeps the microphone closed for the
     * full 140 ms cue on every Android device rather than racing playback.
     */
    private fun finishPendingPlayback(code: String? = null, message: String? = null) {
        val callback = playbackResult ?: return
        playbackResult = null
        if (code == null) callback.success(null) else callback.error(code, message, null)
    }

    fun dispose() {
        player?.release()
        player = null
        finishPendingPlayback()
        methods.setMethodCallHandler(null)
    }
}
