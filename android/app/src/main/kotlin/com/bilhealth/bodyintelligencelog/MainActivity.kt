package com.bilhealth.bodyintelligencelog

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.os.Build
import android.provider.ContactsContract
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

class MainActivity : FlutterFragmentActivity() {
    private var speechBridge: BILSpeechBridge? = null
    private var textToSpeechBridge: BILTextToSpeechBridge? = null
    private var micSoundBridge: BILMicSoundBridge? = null
    private var healthBridge: BILGlobalHealthBridge? = null
    private var fitnessBleBridge: BILFitnessBleBridge? = null
    private var playIntegrityBridge: BILPlayIntegrityBridge? = null
    private var facebookOAuthBridge: BILFacebookOAuthBridge? = null
    private var pushChannel: MethodChannel? = null
    private val pendingRemotePushDeepLinks = ArrayDeque<String>()
    private var remotePushDeliveryInFlight = false
    private val speechPermissionLauncher: ActivityResultLauncher<String> =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            speechBridge?.onMicrophonePermissionResult(granted)
        }
    private val pushProvider: BILPushProvider = BILUnconfiguredPushProvider()
    private val healthPermissionLauncher: ActivityResultLauncher<Set<String>> =
        registerForActivityResult(BILGlobalHealthBridge.permissionContract(this)) { granted ->
            healthBridge?.onPermissionsResult(granted)
        }
    private val blePermissionLauncher: ActivityResultLauncher<Array<String>> =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { grants ->
            val result = pendingBlePermissionResult
            pendingBlePermissionResult = null
            if (grants.values.all { it }) {
                result?.success(null)
            } else {
                result?.error("bluetooth_permission_denied", null, null)
            }
        }
    private var pendingBlePermissionResult: io.flutter.plugin.common.MethodChannel.Result? = null
    private var pendingContactResult: io.flutter.plugin.common.MethodChannel.Result? = null
    private val contactPickerLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { response ->
            val result = pendingContactResult
            pendingContactResult = null
            if (response.resultCode != Activity.RESULT_OK || response.data?.data == null) {
                result?.success(null)
                return@registerForActivityResult
            }
            val uri = response.data!!.data!!
            try {
                contentResolver.query(
                    uri,
                    arrayOf(
                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                        ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ),
                    null,
                    null,
                    null,
                )?.use { cursor ->
                    if (!cursor.moveToFirst()) {
                        result?.success(null)
                    } else {
                        result?.success(
                            mapOf(
                                "name" to (cursor.getString(0) ?: ""),
                                "phone" to (cursor.getString(1) ?: ""),
                            ),
                        )
                    }
                } ?: result?.success(null)
            } catch (_: SecurityException) {
                result?.error("contact_access_denied", null, null)
            } catch (_: Exception) {
                result?.error("contact_picker_failed", null, null)
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bil/launch",
        ).setMethodCallHandler { call, result ->
            if (call.method == "ready") {
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        speechBridge = BILSpeechBridge(this, flutterEngine.dartExecutor.binaryMessenger) {
            speechPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
        textToSpeechBridge = BILTextToSpeechBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        micSoundBridge = BILMicSoundBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        healthBridge = BILGlobalHealthBridge(this, flutterEngine.dartExecutor.binaryMessenger, healthPermissionLauncher)
        playIntegrityBridge = BILPlayIntegrityBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        facebookOAuthBridge = BILFacebookOAuthBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        BILSystemCryptoBridge(flutterEngine.dartExecutor.binaryMessenger)
        captureRemotePushIntent(intent)
        pushChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PUSH_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "providerStatus" -> result.success(pushProvider.status())
                    "requestToken" -> pushProvider.requestToken(result)
                    "deleteToken" -> pushProvider.deleteToken(result)
                    "takeInitialPayload" -> {
                        val payloads = pendingRemotePushDeepLinks.toList()
                        pendingRemotePushDeepLinks.clear()
                        result.success(payloads)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bil/contact_picker").setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> {
                    if (pendingContactResult != null) {
                        result.error("contact_picker_in_progress", null, null)
                    } else {
                        pendingContactResult = result
                        contactPickerLauncher.launch(
                            Intent(
                                Intent.ACTION_PICK,
                                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                            ),
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
        fitnessBleBridge = BILFitnessBleBridge(this, flutterEngine.dartExecutor.binaryMessenger) { result ->
            if (pendingBlePermissionResult != null) {
                result.error("permission_request_in_progress", null, null)
            } else {
                pendingBlePermissionResult = result
                val permissions = if (Build.VERSION.SDK_INT >= 31) arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT) else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
                blePermissionLauncher.launch(permissions)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = remotePushDeepLink(intent) ?: return
        intent.removeExtra(REMOTE_PUSH_DEEP_LINK_EXTRA)
        enqueueRemotePushDeepLink(payload)
        deliverNextRemotePushTap()
    }

    private fun deliverNextRemotePushTap() {
        if (remotePushDeliveryInFlight) return
        val payload = pendingRemotePushDeepLinks.peekFirst() ?: return
        val channel = pushChannel ?: return
        remotePushDeliveryInFlight = true
        channel.invokeMethod(
            "notificationTap",
            payload,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    remotePushDeliveryInFlight = false
                    if (result == true && pendingRemotePushDeepLinks.peekFirst() == payload) {
                        pendingRemotePushDeepLinks.removeFirst()
                        deliverNextRemotePushTap()
                    }
                }

                override fun error(
                    errorCode: String,
                    errorMessage: String?,
                    errorDetails: Any?,
                ) {
                    remotePushDeliveryInFlight = false
                }

                override fun notImplemented() {
                    remotePushDeliveryInFlight = false
                }
            },
        )
    }

    private fun captureRemotePushIntent(intent: Intent?) {
        remotePushDeepLink(intent)?.let { payload ->
            enqueueRemotePushDeepLink(payload)
            intent?.removeExtra(REMOTE_PUSH_DEEP_LINK_EXTRA)
        }
    }

    private fun enqueueRemotePushDeepLink(payload: String) {
        if (pendingRemotePushDeepLinks.contains(payload)) return
        if (pendingRemotePushDeepLinks.size >= MAX_PENDING_PUSH_TAPS) return
        pendingRemotePushDeepLinks.addLast(payload)
    }

    private fun remotePushDeepLink(intent: Intent?): String? {
        val value = intent?.getStringExtra(REMOTE_PUSH_DEEP_LINK_EXTRA)
            ?.trim()
            ?.takeIf { it.isNotEmpty() && it.length <= MAX_PUSH_PAYLOAD_LENGTH }
            ?: return null
        return value.takeIf {
            runCatching { android.net.Uri.parse(it).scheme.equals("bil", ignoreCase = true) }
                .getOrDefault(false)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        speechBridge?.dispose()
        speechBridge = null
        textToSpeechBridge?.dispose()
        textToSpeechBridge = null
        micSoundBridge?.dispose()
        micSoundBridge = null
        pendingBlePermissionResult?.error("activity_disposed", null, null)
        pendingBlePermissionResult = null
        pendingContactResult?.error("activity_disposed", null, null)
        pendingContactResult = null
        fitnessBleBridge?.dispose()
        fitnessBleBridge = null
        healthBridge?.dispose()
        healthBridge = null
        playIntegrityBridge?.dispose()
        playIntegrityBridge = null
        facebookOAuthBridge?.dispose()
        facebookOAuthBridge = null
        pushChannel?.setMethodCallHandler(null)
        pushChannel = null
        pendingRemotePushDeepLinks.clear()
        remotePushDeliveryInFlight = false
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val PUSH_CHANNEL = "bil/push"
        private const val REMOTE_PUSH_DEEP_LINK_EXTRA = "deep_link"
        private const val MAX_PUSH_PAYLOAD_LENGTH = 512
        private const val MAX_PENDING_PUSH_TAPS = 32
    }
}
