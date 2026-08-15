package com.kadem.bil

import android.Manifest
import android.os.Build
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var speechBridge: BILSpeechBridge? = null
    private val speechPermissionLauncher: ActivityResultLauncher<String> =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            speechBridge?.onMicrophonePermissionResult(granted)
        }
    private val pushProvider: BILPushProvider = BILUnconfiguredPushProvider()
    private val healthPermissionLauncher: ActivityResultLauncher<Set<String>> =
        registerForActivityResult(BILGlobalHealthBridge.permissionContract(this)) {
            // Permission state is read from Health Connect after this callback; no health payload is logged.
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speechBridge = BILSpeechBridge(this, flutterEngine.dartExecutor.binaryMessenger) {
            speechPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
        BILGlobalHealthBridge(this, flutterEngine.dartExecutor.binaryMessenger, healthPermissionLauncher)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bil/push").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestToken" -> pushProvider.requestToken(result)
                "deleteToken" -> pushProvider.deleteToken(result)
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
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
