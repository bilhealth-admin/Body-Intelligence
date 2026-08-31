import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/cloud_platform/services/aes_gcm_cloud_payload_cipher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system AES-GCM keeps the durable v1 envelope contract', () async {
    final cipher = AesGcmCloudPayloadCipher(
      Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
      primitive: const _AuthenticatedTestPrimitive(),
    );
    final clear = <String, Object?>{
      'weight': 90.4,
      'note': 'private-health-note',
      'nested': <String, Object?>{'water': 2750},
    };

    final protected = await cipher.encrypt(clear);

    expect(protected['alg'], 'A256GCM');
    expect(protected['_bil_cipher_v'], 1);
    expect(base64Url.decode(protected['nonce']! as String), hasLength(12));
    expect(jsonEncode(protected), isNot(contains('private-health-note')));
    expect(await cipher.decrypt(protected), clear);
  });

  test('system AES-GCM rejects tampered protected bytes', () async {
    final cipher = AesGcmCloudPayloadCipher(
      Uint8List(32)..fillRange(0, 32, 7),
      primitive: const _AuthenticatedTestPrimitive(),
    );
    final protected = await cipher.encrypt(<String, Object?>{'value': 1});
    final bytes = base64Url.decode(protected['ciphertext']! as String);
    bytes[bytes.length - 1] ^= 1;
    final tampered = <String, Object?>{
      ...protected,
      'ciphertext': base64Url.encode(bytes),
    };

    await expectLater(cipher.decrypt(tampered), throwsA(isA<StateError>()));
  });

  test('system AES-GCM rejects non-256-bit keys', () {
    expect(
      () => AesGcmCloudPayloadCipher(
        Uint8List(31),
        primitive: const _AuthenticatedTestPrimitive(),
      ),
      throwsArgumentError,
    );
  });
}

/// Test-only authenticated transform. Production has no Dart cipher fallback.
final class _AuthenticatedTestPrimitive implements SystemAesGcmPrimitive {
  const _AuthenticatedTestPrimitive();

  static const _mask = 0x5a;
  static const _tagByte = 0xa5;

  @override
  bool get isSupported => true;

  @override
  Future<SystemAesGcmSealedPayload> encrypt({
    required Uint8List key,
    required Uint8List plaintext,
  }) async {
    final nonce = Uint8List.fromList(List<int>.generate(12, (index) => index));
    final protectedBytes = Uint8List.fromList(<int>[
      ...plaintext.map((value) => value ^ _mask),
      ...List<int>.filled(16, _tagByte),
    ]);
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
    if (protectedBytes.length < 16 ||
        protectedBytes
            .sublist(protectedBytes.length - 16)
            .any((value) => value != _tagByte)) {
      throw StateError('Authentication failed.');
    }
    return Uint8List.fromList(
      protectedBytes
          .sublist(0, protectedBytes.length - 16)
          .map((value) => value ^ _mask)
          .toList(growable: false),
    );
  }
}
