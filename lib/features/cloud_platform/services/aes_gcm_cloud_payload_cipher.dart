import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cloud_platform_ports.dart';

/// Small seam around the operating-system AES-GCM implementation.
///
/// Production uses CryptoKit on iOS and JCA/Android's platform provider on
/// Android. Keeping this seam injectable lets the envelope and migration
/// contract be tested without bundling a second cryptographic implementation.
abstract interface class SystemAesGcmPrimitive {
  bool get isSupported;

  Future<SystemAesGcmSealedPayload> encrypt({
    required Uint8List key,
    required Uint8List plaintext,
  });

  Future<Uint8List> decrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List protectedBytes,
  });
}

final class SystemAesGcmSealedPayload {
  factory SystemAesGcmSealedPayload({
    required Uint8List nonce,
    required Uint8List protectedBytes,
  }) => SystemAesGcmSealedPayload._(
    Uint8List.fromList(nonce),
    Uint8List.fromList(protectedBytes),
  );

  const SystemAesGcmSealedPayload._(this.nonce, this.protectedBytes);

  final Uint8List nonce;
  final Uint8List protectedBytes;
}

final class MethodChannelSystemAesGcmPrimitive
    implements SystemAesGcmPrimitive {
  const MethodChannelSystemAesGcmPrimitive();

  static const MethodChannel _channel = MethodChannel('bil/system_crypto');

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<SystemAesGcmSealedPayload> encrypt({
    required Uint8List key,
    required Uint8List plaintext,
  }) async {
    final response = await _channel.invokeMapMethod<String, Object?>(
      'encryptAes256Gcm',
      <String, Object?>{'key': key, 'plaintext': plaintext},
    );
    final nonce = response?['nonce'];
    final protectedBytes = response?['protected'];
    if (nonce is! Uint8List || protectedBytes is! Uint8List) {
      throw const FormatException('Invalid system AES-GCM response.');
    }
    return SystemAesGcmSealedPayload(
      nonce: nonce,
      protectedBytes: protectedBytes,
    );
  }

  @override
  Future<Uint8List> decrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List protectedBytes,
  }) async {
    final response = await _channel.invokeMethod<Uint8List>(
      'decryptAes256Gcm',
      <String, Object?>{
        'key': key,
        'nonce': nonce,
        'protected': protectedBytes,
      },
    );
    if (response == null) {
      throw const FormatException('Invalid system AES-GCM plaintext.');
    }
    return response;
  }
}

/// Authenticated AES-256-GCM envelope for durable cloud payloads.
///
/// The v1 wire format is deliberately unchanged from the former pure-Dart
/// implementation: a 96-bit nonce plus ciphertext with its 128-bit GCM tag
/// appended. Therefore already persisted outbox, inbox and cloud records stay
/// decryptable while the cryptographic operation is supplied by the OS.
final class AesGcmCloudPayloadCipher implements CloudPayloadCipher {
  factory AesGcmCloudPayloadCipher(
    Uint8List key, {
    SystemAesGcmPrimitive primitive =
        const MethodChannelSystemAesGcmPrimitive(),
  }) {
    if (key.length != _keyLength) {
      throw ArgumentError.value(key.length, 'key', 'AES-256 requires 32 bytes');
    }
    return AesGcmCloudPayloadCipher._(Uint8List.fromList(key), primitive);
  }

  const AesGcmCloudPayloadCipher._(this._key, this._primitive);

  static const _version = 1;
  static const _algorithm = 'A256GCM';
  static const _keyLength = 32;
  static const _nonceLength = 12;
  static const _tagLength = 16;

  final Uint8List _key;
  final SystemAesGcmPrimitive _primitive;

  @override
  bool get isAvailable => _key.length == _keyLength && _primitive.isSupported;

  @override
  Future<Map<String, Object?>> encrypt(Map<String, Object?> cleartext) async {
    if (!isAvailable) {
      throw StateError('System AES-256-GCM is unavailable.');
    }
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(cleartext)));
    final sealed = await _primitive.encrypt(key: _key, plaintext: plaintext);
    if (sealed.nonce.length != _nonceLength ||
        sealed.protectedBytes.length < _tagLength) {
      throw const FormatException('Invalid system AES-GCM output.');
    }
    return <String, Object?>{
      '_bil_cipher_v': _version,
      'alg': _algorithm,
      'nonce': base64Url.encode(sealed.nonce),
      'ciphertext': base64Url.encode(sealed.protectedBytes),
    };
  }

  @override
  Future<Map<String, Object?>> decrypt(Map<String, Object?> ciphertext) async {
    if (!isAvailable) {
      throw StateError('System AES-256-GCM is unavailable.');
    }
    if (ciphertext['_bil_cipher_v'] != _version ||
        ciphertext['alg'] != _algorithm ||
        ciphertext['nonce'] is! String ||
        ciphertext['ciphertext'] is! String) {
      throw const FormatException('Unsupported BIL cloud cipher envelope.');
    }
    final nonce = _decode(ciphertext['nonce']! as String, 'nonce');
    if (nonce.length != _nonceLength) {
      throw const FormatException('Invalid BIL cloud cipher nonce.');
    }
    final protectedBytes = _decode(
      ciphertext['ciphertext']! as String,
      'ciphertext',
    );
    if (protectedBytes.length < _tagLength) {
      throw const FormatException('Invalid BIL cloud cipher payload.');
    }
    final clearBytes = await _primitive.decrypt(
      key: _key,
      nonce: nonce,
      protectedBytes: protectedBytes,
    );
    final decoded = jsonDecode(utf8.decode(clearBytes));
    if (decoded is! Map) {
      throw const FormatException('Invalid decrypted BIL cloud payload.');
    }
    return Map<String, Object?>.from(decoded);
  }

  static Uint8List _decode(String value, String field) {
    try {
      return Uint8List.fromList(base64Url.decode(value));
    } on FormatException {
      throw FormatException('Malformed BIL cloud $field.');
    }
  }
}
