package com.bilhealth.bodyintelligencelog

import android.content.ActivityNotFoundException
import android.net.Uri
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Opens Facebook OAuth in a Custom Tab and never falls back to a WebView. */
class BILFacebookOAuthBridge(
    private val activity: FlutterFragmentActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "openCustomTab") {
            result.notImplemented()
            return
        }

        val rawUrl = call.argument<String>("url")?.trim().orEmpty()
        val uri = runCatching { Uri.parse(rawUrl) }.getOrNull()
        if (uri == null || !isTrustedAuthorizationUri(uri)) {
            result.error(
                "invalid_facebook_oauth_url",
                "Rejected an untrusted Facebook authorization address.",
                null,
            )
            return
        }

        val providerPackage = runCatching {
            CustomTabsClient.getPackageName(activity, emptyList())
        }.getOrNull()
        if (providerPackage.isNullOrBlank()) {
            result.success(false)
            return
        }

        val customTab = CustomTabsIntent.Builder()
            .setShowTitle(true)
            .setShareState(CustomTabsIntent.SHARE_STATE_OFF)
            .build()
        customTab.intent.setPackage(providerPackage)
        try {
            customTab.launchUrl(activity, uri)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        } catch (_: SecurityException) {
            result.success(false)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun isTrustedAuthorizationUri(uri: Uri): Boolean {
        if (!uri.isHierarchical ||
            !uri.scheme.equals("https", ignoreCase = true) ||
            !uri.host.equals(SUPABASE_AUTH_HOST, ignoreCase = true) ||
            (uri.port != -1 && uri.port != 443) ||
            !uri.userInfo.isNullOrEmpty() ||
            uri.fragment != null ||
            uri.path != SUPABASE_AUTHORIZE_PATH
        ) {
            return false
        }
        return runCatching {
            uri.getQueryParameters("provider") == listOf("facebook") &&
                uri.getQueryParameters("redirect_to") == listOf(REDIRECT_URI)
        }.getOrDefault(false)
    }

    companion object {
        private const val CHANNEL = "bil/facebook_oauth"
        private const val SUPABASE_AUTH_HOST = "tgmanzhqulksykhslrzb.supabase.co"
        private const val SUPABASE_AUTHORIZE_PATH = "/auth/v1/authorize"
        private const val REDIRECT_URI = "https://www.bilhealth.com/auth/callback"
    }
}
