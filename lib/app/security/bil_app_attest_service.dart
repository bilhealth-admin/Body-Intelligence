import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bil_integrity_exception.dart';

/// iOS App Attest client. App Attest objects and assertions are opaque here;
/// only BIL's backend verifies them and issues the one-use grant.
final class BilAppAttestService {
  BilAppAttestService._();

  static final BilAppAttestService instance = BilAppAttestService._();

  static const MethodChannel _channel = MethodChannel('bil/app_attest');

  Future<void> _authorizationTail = Future<void>.value();

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<String> authorize({
    required String action,
    required String payloadDigest,
  }) {
    // A new installation can attest a key only once. Serialize the first
    // registration and subsequent counters so concurrent sensitive actions do
    // not race two registrations or strand a lower assertion counter.
    final result = _authorizationTail.then(
      (_) => _authorize(action: action, payloadDigest: payloadDigest),
    );
    _authorizationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<String> _authorize({
    required String action,
    required String payloadDigest,
  }) async {
    if (!supported) {
      throw const BilIntegrityException('app_attest_not_supported');
    }

    late final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } on Object {
      throw const BilIntegrityException('cloud_not_initialized');
    }
    final user = client.auth.currentUser;
    if (user == null || client.auth.currentSession == null) {
      throw const BilIntegrityException('authentication_required');
    }

    final nativeSupported = await _channel.invokeMethod<bool>('isSupported');
    if (nativeSupported != true) {
      throw const BilIntegrityException('app_attest_not_supported');
    }

    var keyId = await _channel.invokeMethod<String>('keyId', <String, Object?>{
      'accountId': user.id,
    });
    keyId = keyId?.trim();
    if (keyId == null || keyId.isEmpty) {
      keyId = (await _channel.invokeMethod<String>(
        'generateKey',
        <String, Object?>{'accountId': user.id},
      ))?.trim();
    }
    if (keyId == null || keyId.isEmpty) {
      throw const BilIntegrityException('app_attest_key_unavailable');
    }

    final challenge = await _invoke(client, <String, Object?>{
      'operation': 'challenge',
      'action': action,
      'payload_digest': payloadDigest,
      'key_id': keyId,
    });
    final challengeId = challenge['challenge_id']?.toString().trim() ?? '';
    final challengeValue = challenge['challenge']?.toString().trim() ?? '';
    final registrationRequired = challenge['registration_required'] == true;
    if (challengeId.isEmpty || challengeValue.isEmpty) {
      throw const BilIntegrityException('app_attest_challenge_invalid');
    }

    if (registrationRequired) {
      return _register(
        client: client,
        accountId: user.id,
        keyId: keyId,
        challengeId: challengeId,
        challenge: challengeValue,
      );
    }
    return _assert(
      client: client,
      accountId: user.id,
      keyId: keyId,
      challengeId: challengeId,
      challenge: challengeValue,
      action: action,
      payloadDigest: payloadDigest,
    );
  }

  Future<String> _register({
    required SupabaseClient client,
    required String accountId,
    required String keyId,
    required String challengeId,
    required String challenge,
  }) async {
    final challengeBytes = _decodeBase64Url(challenge);
    final clientDataHash = sha256.convert(challengeBytes).bytes;
    var attestationObject = '';
    try {
      attestationObject = await _invokeNativeWithServerRetry(
        'attestKey',
        <String, Object?>{
          'keyId': keyId,
          'clientDataHash': base64.encode(clientDataHash),
        },
      );
      if (attestationObject.isEmpty) {
        throw const BilIntegrityException('app_attest_object_empty');
      }
    } on PlatformException catch (error) {
      if (!_isRetryable(error)) {
        await _discardKey(accountId: accountId, keyId: keyId);
      }
      throw BilIntegrityException(
        _isRetryable(error)
            ? 'app_attest_server_unavailable'
            : 'app_attest_generation_failed',
      );
    }

    try {
      final response = await _invoke(client, <String, Object?>{
        'operation': 'register',
        'challenge_id': challengeId,
        'key_id': keyId,
        'attestation_object': attestationObject,
      });
      return _grantId(response);
    } on Object {
      // A successfully attested key can't safely be registered against a new
      // one-time challenge after an indeterminate server failure.
      await _discardKey(accountId: accountId, keyId: keyId);
      rethrow;
    } finally {
      attestationObject = '';
    }
  }

  Future<String> _assert({
    required SupabaseClient client,
    required String accountId,
    required String keyId,
    required String challengeId,
    required String challenge,
    required String action,
    required String payloadDigest,
  }) async {
    final clientData = utf8.encode(
      'bil-app-attest-v1\n$challengeId\n$action\n$payloadDigest\n$challenge',
    );
    final clientDataHash = sha256.convert(clientData).bytes;
    var assertion = '';
    try {
      assertion = await _invokeNativeWithServerRetry(
        'generateAssertion',
        <String, Object?>{
          'keyId': keyId,
          'clientDataHash': base64.encode(clientDataHash),
        },
      );
      if (assertion.isEmpty) {
        throw const BilIntegrityException('app_attest_assertion_empty');
      }
    } on PlatformException catch (error) {
      if (!_isRetryable(error)) {
        await _discardKey(accountId: accountId, keyId: keyId);
      }
      throw BilIntegrityException(
        _isRetryable(error)
            ? 'app_attest_server_unavailable'
            : 'app_attest_assertion_failed',
      );
    }

    try {
      final response = await _invoke(client, <String, Object?>{
        'operation': 'assert',
        'challenge_id': challengeId,
        'key_id': keyId,
        'assertion': assertion,
      });
      return _grantId(response);
    } finally {
      assertion = '';
    }
  }

  Future<Map<String, Object?>> _invoke(
    SupabaseClient client,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await client.functions.invoke('app-attest', body: body);
      if (response.status != 200 || response.data is! Map) {
        throw const BilIntegrityException('app_attest_backend_rejected');
      }
      return Map<String, Object?>.from(response.data as Map);
    } on BilIntegrityException {
      rethrow;
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['error']?.toString() : null;
      throw BilIntegrityException(code ?? 'app_attest_backend_rejected');
    } on Object {
      throw const BilIntegrityException('app_attest_backend_unavailable');
    }
  }

  String _grantId(Map<String, Object?> response) {
    final grant = response['grant'];
    final id = grant is Map ? grant['id']?.toString().trim() ?? '' : '';
    if (response['allowed'] != true || id.isEmpty) {
      throw BilIntegrityException(
        response['reason']?.toString() ?? 'app_attest_rejected',
      );
    }
    return id;
  }

  Future<void> _discardKey({
    required String accountId,
    required String keyId,
  }) async {
    try {
      await _channel.invokeMethod<void>('discardKey', <String, Object?>{
        'accountId': accountId,
        'keyId': keyId,
      });
    } on Object {
      // The server still rejects the now-unusable key. A later request will
      // fail closed and can attempt replacement again.
    }
  }

  bool _isRetryable(PlatformException error) =>
      error.details is Map && (error.details as Map)['retryable'] == true;

  Future<String> _invokeNativeWithServerRetry(
    String method,
    Map<String, Object?> arguments,
  ) async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        return await _channel.invokeMethod<String>(method, arguments) ?? '';
      } on PlatformException catch (error) {
        if (attempt == 0 && _isRetryable(error)) {
          // Apple requires a server-unavailable attestation retry to reuse the
          // same key and clientDataHash. Keep this retry bounded and JIT.
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }
        rethrow;
      }
    }
    throw const BilIntegrityException('app_attest_native_retry_exhausted');
  }

  Uint8List _decodeBase64Url(String value) {
    final normalized = value.padRight((value.length + 3) ~/ 4 * 4, '=');
    try {
      return base64Url.decode(normalized);
    } on FormatException {
      throw const BilIntegrityException('app_attest_challenge_invalid');
    }
  }
}
