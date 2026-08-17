import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'cloud_platform_ports.dart';

/// Authenticated AES-256-GCM envelope for durable cloud payloads.
///
/// A fresh 96-bit nonce is generated for every encryption. The returned map is
/// intentionally self-describing so future cipher migrations can coexist with
/// already persisted outbox/inbox records.
final class AesGcmCloudPayloadCipher implements CloudPayloadCipher {
  AesGcmCloudPayloadCipher(Uint8List key)
    : _key = Uint8List.fromList(key) {
    if (_key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'AES-256 requires 32 bytes');
    }
  }

  static const _version = 1;
  static const _algorithm = 'A256GCM';
  static const _nonceLength = 12;
  static const _tagBits = 128;

  final Uint8List _key;

  @override
  bool get isAvailable => _key.length == 32;

  @override
  Map<String, Object?> encrypt(Map<String, Object?> cleartext) {
    final nonce = Uint8List(_nonceLength);
    final random = Random.secure();
    for (var index = 0; index < nonce.length; index++) {
      nonce[index] = random.nextInt(256);
    }
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(_key),
          _tagBits,
          nonce,
          Uint8List(0),
        ),
      );
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(cleartext)));
    final protected = cipher.process(plaintext);
    return <String, Object?>{
      '_bil_cipher_v': _version,
      'alg': _algorithm,
      'nonce': base64Url.encode(nonce),
      'ciphertext': base64Url.encode(protected),
    };
  }

  @override
  Map<String, Object?> decrypt(Map<String, Object?> ciphertext) {
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
    final protected = _decode(
      ciphertext['ciphertext']! as String,
      'ciphertext',
    );
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(_key),
          _tagBits,
          nonce,
          Uint8List(0),
        ),
      );
    final clearBytes = cipher.process(protected);
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
