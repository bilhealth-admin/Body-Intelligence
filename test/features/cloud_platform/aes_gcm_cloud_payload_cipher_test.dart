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

  test(
    'legacy unpadded envelopes preserve protected bytes and authenticate',
    () async {
      final cipher = AesGcmCloudPayloadCipher(
        Uint8List(32),
        primitive: const _AuthenticatedTestPrimitive(),
      );
      final remainders = <int>{};
      for (var length = 0; length < 3; length++) {
        final clear = <String, Object?>{
          'note': List.filled(length, 'x').join(),
        };
        final envelope = await cipher.encrypt(clear);
        final unpadded = (envelope['ciphertext']! as String).replaceAll(
          '=',
          '',
        );
        remainders.add(unpadded.length % 4);
        final legacy = <String, Object?>{...envelope, 'ciphertext': unpadded};
        expect(await cipher.decrypt(legacy), clear);
        expect(
          legacy['ciphertext'],
          unpadded,
          reason: 'Never mutate stored input',
        );

        final damaged = base64Url.decode(base64Url.normalize(unpadded));
        damaged[damaged.length - 1] ^= 1;
        await expectLater(
          cipher.decrypt({
            ...legacy,
            'ciphertext': base64Url.encode(damaged).replaceAll('=', ''),
          }),
          throwsA(isA<StateError>()),
        );
      }
      expect(remainders, {0, 2, 3});
    },
  );

  test(
    'normalization still rejects invalid encodings and envelope lengths',
    () async {
      final cipher = AesGcmCloudPayloadCipher(
        Uint8List(32),
        primitive: const _AuthenticatedTestPrimitive(),
      );
      final envelope = await cipher.encrypt({'value': 1});
      for (final invalid in [
        'A',
        'AA=',
        'AA===',
        'AA=A',
        'AA A',
        'AA\nA',
        'AA%3D%3D',
        'AA!A',
      ]) {
        await expectLater(
          cipher.decrypt({...envelope, 'ciphertext': invalid}),
          throwsFormatException,
          reason: 'Malformed encoding remains rejected',
        );
      }
      for (final change in <Map<String, Object?>>[
        {'nonce': base64Url.encode(Uint8List(11)).replaceAll('=', '')},
        {'ciphertext': base64Url.encode(Uint8List(15)).replaceAll('=', '')},
        {'_bil_cipher_v': 2},
        {'alg': 'none'},
      ]) {
        await expectLater(
          cipher.decrypt({...envelope, ...change}),
          throwsFormatException,
        );
      }
    },
  );
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
