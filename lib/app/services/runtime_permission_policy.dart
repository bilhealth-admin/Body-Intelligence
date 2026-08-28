import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum BilRuntimeCapability {
  camera,
  microphone,
  speechRecognition,
  notifications,
}

enum BilRuntimePermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Central just-in-time phone-permission boundary.
///
/// Photo selection intentionally does not appear here: BIL uses the Android
/// system photo picker / iOS PHPicker and therefore must not request broad
/// media-library access. Health and Bluetooth remain in their feature-native
/// category pickers because those requests are granular and user-selected.
class BilRuntimePermissionPolicy {
  const BilRuntimePermissionPolicy();

  bool get _usesMobileRuntimePermissions =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Permission permissionFor(BilRuntimeCapability capability) =>
      switch (capability) {
        BilRuntimeCapability.camera => Permission.camera,
        BilRuntimeCapability.microphone => Permission.microphone,
        BilRuntimeCapability.speechRecognition => Permission.speech,
        BilRuntimeCapability.notifications => Permission.notification,
      };

  Future<BilRuntimePermissionState> status(
    BilRuntimeCapability capability,
  ) async {
    if (!_usesMobileRuntimePermissions) {
      return BilRuntimePermissionState.granted;
    }
    return _state(await permissionFor(capability).status);
  }

  Future<BilRuntimePermissionState> request(
    BilRuntimeCapability capability,
  ) async {
    if (!_usesMobileRuntimePermissions) {
      return BilRuntimePermissionState.granted;
    }
    return _state(await permissionFor(capability).request());
  }

  Future<bool> openSettings() => openAppSettings();

  BilRuntimePermissionState _state(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return BilRuntimePermissionState.granted;
    }
    if (status.isPermanentlyDenied) {
      return BilRuntimePermissionState.permanentlyDenied;
    }
    if (status.isRestricted) return BilRuntimePermissionState.restricted;
    return BilRuntimePermissionState.denied;
  }
}
