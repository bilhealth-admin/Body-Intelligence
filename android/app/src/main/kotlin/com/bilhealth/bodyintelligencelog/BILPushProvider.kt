package com.bilhealth.bodyintelligencelog

import io.flutter.plugin.common.MethodChannel

/**
 * Native provider seam used by the production Android flavor to connect FCM.
 * The release-safe default fails closed until Firebase credentials and the
 * provider implementation are supplied; it never manufactures a device token.
 */
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
