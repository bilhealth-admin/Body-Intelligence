package com.kadem.bil

import io.flutter.plugin.common.MethodChannel

/**
 * Native provider seam used by the production Android flavor to connect FCM.
 * The release-safe default fails closed until Firebase credentials and the
 * provider implementation are supplied; it never manufactures a device token.
 */
interface BILPushProvider {
    fun requestToken(result: MethodChannel.Result)
    fun deleteToken(result: MethodChannel.Result)
}

class BILUnconfiguredPushProvider : BILPushProvider {
    override fun requestToken(result: MethodChannel.Result) {
        result.error(
            "push_provider_not_configured",
            "FCM credentials and the production provider are not configured.",
            null,
        )
    }

    override fun deleteToken(result: MethodChannel.Result) = result.success(null)
}
