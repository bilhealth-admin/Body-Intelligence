package com.bilhealth.bodyintelligencelog

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge for Google Play Integrity Standard requests.
 *
 * The client never decodes or trusts an integrity verdict. It only prepares
 * the Standard token provider and returns Google's encrypted token to Dart,
 * which forwards it to BIL's authenticated Supabase backend.
 */
class BILPlayIntegrityBridge(
    context: Context,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val manager =
        IntegrityManagerFactory.createStandard(context.applicationContext)

    private var provider: StandardIntegrityManager.StandardIntegrityTokenProvider? = null
    private var preparing = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> {
                    val projectNumber =
                        call.argument<Number>("cloudProjectNumber")?.toLong()
                    if (projectNumber == null || projectNumber <= 0L) {
                        result.error(
                            "invalid_cloud_project_number",
                            null,
                            null,
                        )
                    } else {
                        prepare(projectNumber, result)
                    }
                }

                "requestToken" -> {
                    val requestHash =
                        call.argument<String>("requestHash")?.trim().orEmpty()
                    if (requestHash.isEmpty() || requestHash.length >= 500) {
                        result.error("invalid_request_hash", null, null)
                    } else {
                        requestToken(requestHash, result)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun prepare(
        projectNumber: Long,
        result: MethodChannel.Result,
    ) {
        if (provider != null) {
            result.success(true)
            return
        }
        if (preparing) {
            result.error("integrity_prepare_in_progress", null, null)
            return
        }

        preparing = true
        manager.prepareIntegrityToken(
            StandardIntegrityManager.PrepareIntegrityTokenRequest.builder()
                .setCloudProjectNumber(projectNumber)
                .build(),
        ).addOnSuccessListener { tokenProvider ->
            provider = tokenProvider
            preparing = false
            result.success(true)
        }.addOnFailureListener { error ->
            provider = null
            preparing = false
            result.error(
                "integrity_prepare_failed",
                error.javaClass.simpleName,
                null,
            )
        }
    }

    private fun requestToken(
        requestHash: String,
        result: MethodChannel.Result,
    ) {
        val tokenProvider = provider
        if (tokenProvider == null) {
            result.error("integrity_provider_not_ready", null, null)
            return
        }

        tokenProvider.request(
            StandardIntegrityManager.StandardIntegrityTokenRequest.builder()
                .setRequestHash(requestHash)
                .build(),
        ).addOnSuccessListener { response ->
            result.success(response.token())
        }.addOnFailureListener { error ->
            // Force a fresh prepare on the next attempt.
            provider = null
            result.error(
                "integrity_token_failed",
                error.javaClass.simpleName,
                null,
            )
        }
    }

    fun dispose() {
        provider = null
        channel.setMethodCallHandler(null)
    }

    private companion object {
        const val CHANNEL = "bil/play_integrity"
    }
}
