import 'package:flutter/foundation.dart';

import 'bil_app_attest_service.dart';
import 'bil_integrity_exception.dart';
import 'bil_integrity_payload.dart';
import 'bil_play_integrity_service.dart';

/// Produces a one-use, server-verified integrity grant immediately before a
/// sensitive request. No verdict is trusted or decoded in Flutter.
final class BilMobileIntegrityService {
  BilMobileIntegrityService({
    BilPlayIntegrityService? playIntegrity,
    BilAppAttestService? appAttest,
    TargetPlatform Function()? platform,
    bool Function()? isWeb,
    bool Function()? integrityRequired,
  }) : _playIntegrity = playIntegrity ?? BilPlayIntegrityService.instance,
       _appAttest = appAttest ?? BilAppAttestService.instance,
       _platform = platform ?? (() => defaultTargetPlatform),
       _isWeb = isWeb ?? (() => kIsWeb),
       _integrityRequired = integrityRequired ?? (() => _requiredByBuild);

  static final BilMobileIntegrityService instance = BilMobileIntegrityService();

  final BilPlayIntegrityService _playIntegrity;
  final BilAppAttestService _appAttest;
  final TargetPlatform Function() _platform;
  final bool Function() _isWeb;
  final bool Function() _integrityRequired;

  // Keep false for existing production clients while the migration, both
  // attestation functions, server configuration and guarded functions are
  // staged. Signed release workflows turn this on only behind their backend
  // readiness gate.
  static const _requiredByBuild = bool.fromEnvironment(
    'BIL_MOBILE_INTEGRITY_REQUIRED',
    defaultValue: false,
  );

  Future<Map<String, Object?>> protect({
    required String action,
    required Map<String, Object?> payload,
  }) async {
    if (!RegExp(r'^[a-z][a-z0-9_.:-]{1,79}$').hasMatch(action)) {
      throw const BilIntegrityException('invalid_integrity_action');
    }
    if (payload.containsKey('_integrity')) {
      throw const BilIntegrityException('reserved_integrity_envelope');
    }
    if (!_integrityRequired()) {
      return <String, Object?>{...payload};
    }
    if (_isWeb()) {
      throw const BilIntegrityException('mobile_integrity_not_supported');
    }

    final payloadDigest = bilIntegrityPayloadDigest(payload);
    final platform = _platform();
    final grantId = switch (platform) {
      TargetPlatform.android => await _playIntegrity.authorize(
        action: action,
        payloadDigest: payloadDigest,
      ),
      TargetPlatform.iOS => await _appAttest.authorize(
        action: action,
        payloadDigest: payloadDigest,
      ),
      _ => throw const BilIntegrityException('mobile_integrity_not_supported'),
    };

    return <String, Object?>{
      ...payload,
      '_integrity': <String, Object?>{'grant_id': grantId},
    };
  }
}
