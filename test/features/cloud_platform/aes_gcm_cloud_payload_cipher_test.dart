import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/aes_gcm_cloud_payload_cipher.dart';

void main() {
  test('AES-GCM cloud payload round-trips and does not expose cleartext', () {
    final cipher = AesGcmCloudPayloadCipher(
      Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
    );
    final clear = <String, Object?>{
      'weight': 90.4,
      'note': 'private-health-note',
      'nested': <String, Object?>{'water': 2750},
    };

    final protected = cipher.encrypt(clear);

    expect(protected['alg'], 'A256GCM');
    expect(protected['_bil_cipher_v'], 1);
    expect(jsonEncode(protected), isNot(contains('private-health-note')));
    expect(cipher.decrypt(protected), clear);
  });

  test('AES-GCM rejects tampered ciphertext', () {
    final cipher = AesGcmCloudPayloadCipher(Uint8List(32)..fillRange(0, 32, 7));
    final protected = cipher.encrypt(<String, Object?>{'value': 1});
    final bytes = base64Url.decode(protected['ciphertext']! as String);
    bytes[bytes.length - 1] ^= 1;
    final tampered = <String, Object?>{
      ...protected,
      'ciphertext': base64Url.encode(bytes),
    };

    expect(() => cipher.decrypt(tampered), throwsA(anything));
  });
}
