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

class MainActivity : FlutterFragmentActivity() {
    private var speechBridge: BILSpeechBridge? = null
    private var textToSpeechBridge: BILTextToSpeechBridge? = null
    private var healthBridge: BILGlobalHealthBridge? = null
    private var playIntegrityBridge: BILPlayIntegrityBridge? = null
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
        healthBridge = BILGlobalHealthBridge(this, flutterEngine.dartExecutor.binaryMessenger, healthPermissionLauncher)
        playIntegrityBridge = BILPlayIntegrityBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bil/push").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestToken" -> pushProvider.requestToken(result)
                "deleteToken" -> pushProvider.deleteToken(result)
                else -> result.notImplemented()
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
        BILMedicalBleBridge(this, flutterEngine.dartExecutor.binaryMessenger) { result ->
            if (pendingBlePermissionResult != null) {
                result.error("permission_request_in_progress", null, null)
            } else {
                pendingBlePermissionResult = result
                val permissions = if (Build.VERSION.SDK_INT >= 31) arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT) else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
                blePermissionLauncher.launch(permissions)
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        speechBridge?.dispose()
        speechBridge = null
        textToSpeechBridge?.dispose()
        textToSpeechBridge = null
        healthBridge = null
        playIntegrityBridge?.dispose()
        playIntegrityBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
