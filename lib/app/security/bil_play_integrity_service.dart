import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final class BilPlayIntegrityObservation {
  const BilPlayIntegrityObservation({
    required this.allowed,
    required this.trustworthy,
    required this.mode,
    required this.reason,
  });

  final bool allowed;
  final bool trustworthy;
  final String mode;
  final String reason;
}

/// Google Play Integrity Standard requests for Android.
///
/// Verdicts are never decoded or trusted on the device. Google's encrypted
/// token is forwarded to BIL's authenticated backend for verification.
final class BilPlayIntegrityService {
  BilPlayIntegrityService._();

  static final BilPlayIntegrityService instance = BilPlayIntegrityService._();

  static const MethodChannel _channel = MethodChannel('bil/play_integrity');
  static const int _cloudProjectNumber = 1041595138122;
  static const Uuid _uuid = Uuid();

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
    try {
      final ready = await _channel.invokeMethod<bool>(
        'prepare',
        <String, Object?>{
          'cloudProjectNumber': _cloudProjectNumber,
        },
      );
      _prepared = ready == true;
    } on PlatformException {
      _prepared = false;
    } on MissingPluginException {
      _prepared = false;
    }
  }

  Future<BilPlayIntegrityObservation> observe({
    required String action,
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    if (!supported) return _allowUnavailable('platform_not_supported');

    late final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } on Object {
      return _allowUnavailable('cloud_not_initialized');
    }

    if (client.auth.currentSession == null) {
      return _allowUnavailable('authentication_required');
    }

    final requestId = 'pi-${_uuid.v4()}';
    final payloadDigest = sha256
        .convert(
          utf8.encode(
            jsonEncode(_canonicalize(payload)),
          ),
        )
        .toString();

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
        return _allowUnavailable('integrity_token_unavailable');
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
        return _allowUnavailable('integrity_response_invalid');
      }

      return BilPlayIntegrityObservation(
        allowed: data['allowed'] != false,
        trustworthy: data['trustworthy'] == true,
        mode: data['mode']?.toString() ?? 'observe',
        reason: data['reason']?.toString() ?? 'unknown',
      );
    } on Object {
      return _allowUnavailable('integrity_backend_unavailable');
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

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries
          .map((entry) => MapEntry(entry.key.toString(), entry.value))
          .toList()
        ..sort((left, right) => left.key.compareTo(right.key));

      return <String, Object?>{
        for (final entry in entries)
          entry.key: _canonicalize(entry.value),
      };
    }

    if (value is Iterable) {
      return value
          .map<Object?>((item) => _canonicalize(item))
          .toList(growable: false);
    }

    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    return value.toString();
  }

  static BilPlayIntegrityObservation _allowUnavailable(String reason) =>
      BilPlayIntegrityObservation(
        allowed: true,
        trustworthy: false,
        mode: 'observe',
        reason: reason,
      );
}
