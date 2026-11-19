import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'bil_integrity_exception.dart';
import '../../features/community/services/community_owner_operation.dart';

/// Google Play Integrity Standard requests for Android.
///
/// Verdicts are never decoded or trusted on the device. Google's encrypted
/// token is forwarded to BIL's authenticated backend for verification.
final class BilPlayIntegrityService {
  BilPlayIntegrityService._() : _testCloudProjectNumber = null;

  @visibleForTesting
  BilPlayIntegrityService.forTesting({required int cloudProjectNumber})
    : assert(cloudProjectNumber > 0),
      _testCloudProjectNumber = cloudProjectNumber;

  static final BilPlayIntegrityService instance = BilPlayIntegrityService._();

  static const MethodChannel _channel = MethodChannel('bil/play_integrity');
  static const String _cloudProjectNumberValue = String.fromEnvironment(
    'BIL_PLAY_INTEGRITY_PROJECT_NUMBER',
  );
  static const Uuid _uuid = Uuid();

  final int? _testCloudProjectNumber;

  int? get _cloudProjectNumber {
    final testValue = _testCloudProjectNumber;
    if (testValue != null && testValue > 0) return testValue;
    final value = int.tryParse(_cloudProjectNumberValue);
    return value != null && value > 0 ? value : null;
  }

  bool _prepared = false;
  int _prepareEpoch = 0;
  Future<void>? _prepareFuture;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> prepare() {
    if (!supported || _prepared) return Future<void>.value();

    final pending = _prepareFuture;
    if (pending != null) return pending;

    final future = _prepareNative(_prepareEpoch);
    _prepareFuture = future;
    return future.whenComplete(() {
      if (identical(_prepareFuture, future)) _prepareFuture = null;
    });
  }

  Future<void> _prepareNative(int epoch) async {
    final cloudProjectNumber = _cloudProjectNumber;
    if (cloudProjectNumber == null) {
      throw const BilIntegrityException('play_integrity_not_configured');
    }
    try {
      final ready = await _channel.invokeMethod<bool>(
        'prepare',
        <String, Object?>{'cloudProjectNumber': cloudProjectNumber},
      );
      if (epoch == _prepareEpoch) _prepared = ready == true;
    } on PlatformException {
      if (epoch == _prepareEpoch) _prepared = false;
    } on MissingPluginException {
      if (epoch == _prepareEpoch) _prepared = false;
    }
  }

  Future<String> authorize({
    required String action,
    required String payloadDigest,
    bool retainLicenseRecovery = false,
  }) async {
    late final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } on Object {
      throw const BilIntegrityException('cloud_not_initialized');
    }
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      throw const BilIntegrityException('authentication_required');
    }
    // Observe the original authenticated visit BEFORE any native async work.
    return CommunityOwnerOperation.run(
      client: client,
      ownerId: owner,
      action: (_) => _authorize(
        action: action,
        payloadDigest: payloadDigest,
        retainLicenseRecovery: retainLicenseRecovery,
      ),
    );
  }

  Future<String> _authorize({
    required String action,
    required String payloadDigest,
    required bool retainLicenseRecovery,
  }) async {
    if (!supported) {
      throw const BilIntegrityException('play_integrity_not_supported');
    }
    if (_cloudProjectNumber == null) {
      throw const BilIntegrityException('play_integrity_not_configured');
    }

    late final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } on Object {
      throw const BilIntegrityException('cloud_not_initialized');
    }

    if (client.auth.currentSession == null) {
      throw const BilIntegrityException('authentication_required');
    }

    final owner = client.auth.currentUser!.id;
    final requestId = 'pi-${_uuid.v4()}';
    final requestHash = _requestHash(
      action: action,
      requestId: requestId,
      payloadDigest: payloadDigest,
    );

    String integrityToken;
    try {
      if (!_prepared) await prepare();
      integrityToken = await _requestToken(requestHash, retainLicenseRecovery);
    } on Object {
      _prepared = false;
      await prepare();
      try {
        integrityToken = await _requestToken(
          requestHash,
          retainLicenseRecovery,
        );
      } on Object {
        throw const BilIntegrityException('integrity_token_unavailable');
      }
    }

    var keepRecovery = false;
    BilIntegrityException licenseRequired() {
      keepRecovery = retainLicenseRecovery;
      return BilIntegrityException(
        'license_unlicensed',
        recoveryHandle: retainLicenseRecovery ? requestHash : null,
        recoveryOwner: retainLicenseRecovery ? owner : null,
      );
    }

    try {
      CommunityOwnerOperation.checkCurrent();
      final response = await CommunityOwnerOperation.run(
        client: client,
        ownerId: owner,
        action: (_) => client.functions.invoke(
          'play-integrity',
          body: <String, Object?>{
            'request_id': requestId,
            'action': action,
            'payload_digest': payloadDigest,
            'request_hash': requestHash,
            'integrity_token': integrityToken,
          },
        ),
      );

      final data = response.data;
      if (data is! Map) {
        throw const BilIntegrityException('integrity_response_invalid');
      }
      if (_isLicenseDenial(response.status, data)) throw licenseRequired();
      final grant = data['grant'];
      final grantId = grant is Map ? grant['id']?.toString().trim() ?? '' : '';
      if (response.status != 200 ||
          data['allowed'] != true ||
          data['trustworthy'] != true ||
          grantId.isEmpty) {
        throw BilIntegrityException('play_integrity_rejected');
      }
      return grantId;
    } on BilIntegrityException {
      rethrow;
    } on FunctionException catch (error) {
      if (client.auth.currentUser?.id == owner &&
          _isLicenseDenial(error.status, error.details)) {
        throw licenseRequired();
      }
      throw const BilIntegrityException('integrity_backend_unavailable');
    } on Object {
      throw const BilIntegrityException('integrity_backend_unavailable');
    } finally {
      // Do not retain Google's encrypted integrity token in application state.
      integrityToken = '';
      if (!keepRecovery) await releaseLicenseRecovery(requestHash);
    }
  }

  // Only the authenticated backend's exact 403 denial permits remediation.
  static bool _isLicenseDenial(int status, Object? data) =>
      status == 403 &&
      data is Map &&
      data['allowed'] == false &&
      data['trustworthy'] == false &&
      data['reason'] == 'license_unlicensed' &&
      data['mode'] == 'enforce' &&
      data['grant'] == null;

  Future<void> releaseLicenseRecovery(String handle) async {
    try {
      await _channel
          .invokeMethod<void>('releaseToken', {'handle': handle})
          .timeout(const Duration(seconds: 2));
    } on Object {
      // Native leases also expire independently after 60 seconds.
    }
  }

  Future<bool> recoverLicense(BilIntegrityException denial) async {
    final handle = denial.recoveryHandle;
    final owner = denial.recoveryOwner;
    if (denial.code != 'license_unlicensed' ||
        handle == null ||
        owner == null ||
        Supabase.instance.client.auth.currentUser?.id != owner) {
      return false;
    }
    try {
      // Any dialog result is interaction only. A fresh server check follows.
      final code = await _channel.invokeMethod<int>('getLicensed', {
        'handle': handle,
      });
      return code == 3 &&
          Supabase.instance.client.auth.currentUser?.id == owner;
    } on Object {
      return false;
    } finally {
      _prepareEpoch++;
      _prepared = false;
      _prepareFuture = null;
    }
  }

  Future<String> _requestToken(
    String requestHash,
    bool retainForRecovery,
  ) async {
    final token = await _channel.invokeMethod<String>(
      'requestToken',
      <String, Object?>{
        'requestHash': requestHash,
        'retainForRecovery': retainForRecovery,
      },
    );
    if (token == null || token.isEmpty) {
      throw StateError('integrity_token_empty');
    }
    return token;
  }

  static String _requestHash({
    required String action,
    required String requestId,
    required String payloadDigest,
  }) {
    final material = 'bil-integrity-v2\n$action\n$requestId\n$payloadDigest';
    final digestBytes = sha256.convert(utf8.encode(material)).bytes;
    return base64Url.encode(digestBytes).replaceAll('=', '');
  }
}
