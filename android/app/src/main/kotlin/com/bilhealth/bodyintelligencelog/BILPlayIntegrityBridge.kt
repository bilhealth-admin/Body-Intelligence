package com.bilhealth.bodyintelligencelog

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityDialogRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityDialogRequest.StandardIntegrityResponse
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Encrypted tokens and one-use Google remediation responses remain in RAM. */
class BILPlayIntegrityBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val manager = IntegrityManagerFactory.createStandard(activity.applicationContext)
    private val handler = Handler(Looper.getMainLooper())
    private val lease = BILIntegrityTokenLease<StandardIntegrityManager.StandardIntegrityToken>(
        now = { SystemClock.elapsedRealtime() },
    )
    private var provider: StandardIntegrityManager.StandardIntegrityTokenProvider? = null
    private var preparing = false
    private var disposed = false
    private var dialogShowing = false
    private var epoch = 0L
    private var requestSequence = 0L
    private val pending = mutableSetOf<Reply>()

    private inner class Reply(private val result: MethodChannel.Result) {
        private var done = false
        init { pending.add(this) }
        fun success(value: Any?) { if (!done) { done = true; pending.remove(this); result.success(value) } }
        fun error(code: String) { if (!done) { done = true; pending.remove(this); result.error(code, null, null) } }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            val reply = Reply(result)
            if (disposed) { reply.error("integrity_retired"); return@setMethodCallHandler }
            when (call.method) {
                "prepare" -> {
                    val number = call.argument<Number>("cloudProjectNumber")?.toLong()
                    if (number == null || number <= 0L) reply.error("invalid_cloud_project_number")
                    else prepare(number, reply)
                }
                "requestToken" -> {
                    val hash = call.argument<String>("requestHash").orEmpty()
                    if (!Regex("^[A-Za-z0-9_-]{43}$").matches(hash)) reply.error("invalid_request_hash")
                    else requestToken(hash, call.argument<Boolean>("retainForRecovery") == true, reply)
                }
                "getLicensed" -> getLicensed(call.argument<String>("handle").orEmpty(), reply)
                "releaseToken" -> { lease.release(call.argument<String>("handle").orEmpty()); reply.success(null) }
                "reset" -> { retire(reply); reply.success(null) }
                else -> { pending.remove(reply); result.notImplemented() }
            }
        }
    }

    private fun prepare(projectNumber: Long, reply: Reply) {
        if (dialogShowing) { reply.error("integrity_dialog_in_progress"); return }
        if (provider != null) { reply.success(true); return }
        if (preparing) { reply.error("integrity_prepare_in_progress"); return }
        preparing = true
        val visit = epoch
        manager.prepareIntegrityToken(
            StandardIntegrityManager.PrepareIntegrityTokenRequest.builder()
                .setCloudProjectNumber(projectNumber).build(),
        ).addOnSuccessListener { value ->
            if (disposed || visit != epoch) { reply.error("integrity_retired"); return@addOnSuccessListener }
            provider = value; preparing = false; reply.success(true)
        }.addOnFailureListener {
            if (disposed || visit != epoch) { reply.error("integrity_retired"); return@addOnFailureListener }
            provider = null; preparing = false; reply.error("integrity_prepare_failed")
        }
    }

    private fun requestToken(hash: String, retain: Boolean, reply: Reply) {
        val active = provider
        if (active == null || dialogShowing) { reply.error("integrity_provider_not_ready"); return }
        if (retain) lease.clear()
        val visit = epoch
        val sequence = if (retain) ++requestSequence else requestSequence
        active.request(StandardIntegrityManager.StandardIntegrityTokenRequest.builder()
            .setRequestHash(hash).build(),
        ).addOnSuccessListener { response ->
            if (disposed || visit != epoch || (retain && sequence != requestSequence)) {
                reply.error("integrity_retired"); return@addOnSuccessListener
            }
            lease.record(hash, response, retain)
            if (retain) {
                handler.postDelayed({ lease.release(hash) }, TOKEN_TTL_MS)
            }
            reply.success(response.token())
        }.addOnFailureListener {
            if (disposed || visit != epoch || (retain && sequence != requestSequence)) {
                reply.error("integrity_retired"); return@addOnFailureListener
            }
            provider = null; if (retain) lease.clear(); reply.error("integrity_token_failed")
        }
    }

    private fun getLicensed(handle: String, reply: Reply) {
        if (dialogShowing || activity.isFinishing || activity.isDestroyed || !activity.hasWindowFocus()) {
            lease.release(handle); reply.error("integrity_dialog_unavailable"); return
        }
        val response = lease.take(handle)
        if (response == null) { reply.error("integrity_token_expired"); return }
        // Invalidating provider/request callbacks does not cancel onPause: the
        // Google-owned dialog normally pauses this Activity.
        epoch++; requestSequence++; provider = null; preparing = false
        pending.toList().filter { it !== reply }.forEach { it.error("integrity_retired") }
        dialogShowing = true
        val visit = epoch
        val request = StandardIntegrityDialogRequest.builder()
            .setActivity(activity).setTypeCode(GET_LICENSED)
            .setStandardIntegrityResponse(StandardIntegrityResponse.TokenResponse(response)).build()
        try {
            manager.showDialog(request).addOnSuccessListener { code ->
                dialogShowing = false
                if (disposed || visit != epoch) { reply.error("integrity_retired"); return@addOnSuccessListener }
                dialogShowing = false; provider = null; reply.success(code)
            }.addOnFailureListener {
                dialogShowing = false
                if (disposed || visit != epoch) { reply.error("integrity_retired"); return@addOnFailureListener }
                dialogShowing = false; provider = null; reply.error("integrity_dialog_failed")
            }.addOnCanceledListener {
                dialogShowing = false
                if (disposed || visit != epoch) { reply.error("integrity_retired"); return@addOnCanceledListener }
                dialogShowing = false; provider = null; reply.error("integrity_dialog_cancelled")
            }
        } catch (_: Exception) {
            dialogShowing = false; provider = null; reply.error("integrity_dialog_failed")
        }
    }

    private fun retire(except: Reply? = null) {
        epoch++; requestSequence++; provider = null; preparing = false
        lease.clear() // A reset cannot cancel a Google Task/dialog already on screen.
        pending.toList().filter { it !== except }.forEach { it.error("integrity_retired") }
    }

    fun dispose() {
        disposed = true
        retire()
        handler.removeCallbacksAndMessages(null)
        channel.setMethodCallHandler(null)
    }

    private companion object {
        const val CHANNEL = "bil/play_integrity"
        const val GET_LICENSED = 1
        const val TOKEN_TTL_MS = 60_000L
    }
}
