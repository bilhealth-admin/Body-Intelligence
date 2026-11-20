import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class AdSdkPrivacyBoundary {
  Future<bool> permitsSdkRequests();
}

/// Local status only. This boundary never requests ATT or reads an identifier.
final class NoIdfaIosAdSdkBoundary implements AdSdkPrivacyBoundary {
  const NoIdfaIosAdSdkBoundary({
    this.channel = const MethodChannel('bil/ads_privacy'),
    this.statusTimeout = const Duration(seconds: 2),
    this.platformOverride,
  });

  final MethodChannel channel;
  final Duration statusTimeout;
  @visibleForTesting
  final TargetPlatform? platformOverride;

  @override
  Future<bool> permitsSdkRequests() async {
    if (kIsWeb) return false;
    final platform = platformOverride ?? defaultTargetPlatform;
    if (platform == TargetPlatform.android) return true;
    if (platform != TargetPlatform.iOS) return false;
    try {
      final value = await channel
          .invokeMapMethod<String, Object?>('iosAdPrivacyStatus')
          .timeout(statusTimeout);
      // Block legacy authorization, denied/restricted, unsupported/unknown,
      // malformed replies and a missing native status channel alike.
      return value?['trackingAuthorizationStatus'] == 'notDetermined';
    } on Object {
      return false;
    }
  }
}
