import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'bil_integrity_exception.dart';

/// Google Play Integrity Standard requests for Android.
///
/// Verdicts are never decoded or trusted on the device. Google's encrypted
/// token is forwarded to BIL's authenticated backend for verification.
final class BilPlayIntegrityService {
  BilPlayIntegrityService._();

  static final BilPlayIntegrityService instance = BilPlayIntegrityService._();

  static const MethodChannel _channel = MethodChannel('bil/play_integrity');
  static const String _cloudProjectNumberValue = String.fromEnvironment(
    'BIL_PLAY_INTEGRITY_PROJECT_NUMBER',
  );
  static const Uuid _uuid = Uuid();

  static int? get _cloudProjectNumber {
    final value = int.tryParse(_cloudProjectNumberValue);
    return value != null && value > 0 ? value : null;
  }

  bool _prepared = false;
  Future<void>? _prepareFuture;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> prepare() {
    if (!supported || _prepared) return Future<void>.value();

    final pending = _prepareFuture;
    if (pending != null) return pending;

    final future = _prepareNative();
    _prepareFuture = future;
    return future.whenComplete(() => _prepareFuture = null);
  }

  Future<void> _prepareNative() async {
    final cloudProjectNumber = _cloudProjectNumber;
    if (cloudProjectNumber == null) {
      throw const BilIntegrityException('play_integrity_not_configured');
    }
    try {
      final ready = await _channel.invokeMethod<bool>(
        'prepare',
        <String, Object?>{'cloudProjectNumber': cloudProjectNumber},
      );
      _prepared = ready == true;
    } on PlatformException {
      _prepared = false;
    } on MissingPluginException {
      _prepared = false;
    }
  }

  Future<String> authorize({
    required String action,
    required String payloadDigest,
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

    final requestId = 'pi-${_uuid.v4()}';
    final requestHash = _requestHash(
      action: action,
      requestId: requestId,
      payloadDigest: payloadDigest,
    );

    String integrityToken;
    try {
      if (!_prepared) await prepare();
      integrityToken = await _requestToken(requestHash);
    } on Object {
      _prepared = false;
      await prepare();
      try {
        integrityToken = await _requestToken(requestHash);
      } on Object {
        throw const BilIntegrityException('integrity_token_unavailable');
      }
    }

    try {
      final response = await client.functions.invoke(
        'play-integrity',
        body: <String, Object?>{
          'request_id': requestId,
          'action': action,
          'payload_digest': payloadDigest,
          'request_hash': requestHash,
          'integrity_token': integrityToken,
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const BilIntegrityException('integrity_response_invalid');
      }
      final grant = data['grant'];
      final grantId = grant is Map ? grant['id']?.toString().trim() ?? '' : '';
      if (response.status != 200 ||
          data['allowed'] != true ||
          data['trustworthy'] != true ||
          grantId.isEmpty) {
        throw BilIntegrityException(
          data['reason']?.toString() ?? 'play_integrity_rejected',
        );
      }
      return grantId;
    } on BilIntegrityException {
      rethrow;
    } on Object {
      throw const BilIntegrityException('integrity_backend_unavailable');
    } finally {
      // Do not retain Google's encrypted integrity token in application state.
      integrityToken = '';
    }
  }

  Future<String> _requestToken(String requestHash) async {
    final token = await _channel.invokeMethod<String>(
      'requestToken',
      <String, Object?>{'requestHash': requestHash},
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
