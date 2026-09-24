package com.bilhealth.bodyintelligencelog

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.plugin.common.MethodChannel

/** Native provider seam used by the production Android flavor to connect FCM. */
interface BILPushProvider {
    /**
     * Runtime truth consumed before Dart exposes or enables cloud push.
     * A build-time flag alone is not evidence that token registration exists.
     */
    fun status(): Map<String, Any>
    fun requestToken(result: MethodChannel.Result)
    fun deleteToken(result: MethodChannel.Result)
}

class BILUnconfiguredPushProvider : BILPushProvider {
    override fun status(): Map<String, Any> = mapOf(
        "configured" to false,
        "tokenRegistration" to false,
        // MainActivity can route a valid remote deep link even though this
        // placeholder cannot register an FCM token or receive a message.
        "remoteTapRouting" to true,
        "provider" to "unconfigured",
    )

    override fun requestToken(result: MethodChannel.Result) {
        result.error(
            "push_provider_not_configured",
            "FCM credentials and the production provider are not configured.",
            null,
        )
    }

    override fun deleteToken(result: MethodChannel.Result) = result.success(null)
}

class BILFirebasePushProvider(private val context: Context) : BILPushProvider {
    override fun status(): Map<String, Any> {
        val configured = FirebaseApp.getApps(context).isNotEmpty()
        return mapOf(
            "configured" to configured,
            "tokenRegistration" to configured,
            "remoteTapRouting" to true,
            "provider" to "firebase_cloud_messaging",
        )
    }

    override fun requestToken(result: MethodChannel.Result) {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (!task.isSuccessful || task.result.isNullOrBlank()) {
                result.error("fcm_token_unavailable", task.exception?.message, null)
            } else {
                result.success(task.result)
            }
        }
    }

    override fun deleteToken(result: MethodChannel.Result) {
        FirebaseMessaging.getInstance().deleteToken().addOnCompleteListener { task ->
            if (task.isSuccessful) {
                result.success(null)
            } else {
                result.error("fcm_token_delete_failed", task.exception?.message, null)
            }
        }
    }
}
