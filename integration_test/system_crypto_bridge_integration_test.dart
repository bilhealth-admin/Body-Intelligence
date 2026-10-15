import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/cloud_platform/services/aes_gcm_cloud_payload_cipher.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_account_key_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native AES-256-GCM bridge matches the legacy v1 byte layout', (
    tester,
  ) async {
    expect(
      Platform.isAndroid || Platform.isIOS,
      isTrue,
      reason: 'The release gate must run on an Android or iOS target.',
    );

    const primitive = MethodChannelSystemAesGcmPrimitive();
    final plaintext = Uint8List(16);
    final decrypted = await primitive.decrypt(
      key: Uint8List(32),
      nonce: Uint8List(12),
      protectedBytes: _hex(
        'cea7403d4d606b6e074ec5d3baf39d18'
        'd0d1c8a799996bf0265b98b5d48ab919',
      ),
    );

    expect(decrypted, plaintext);

    final sealed = await primitive.encrypt(
      key: Uint8List.fromList(List<int>.generate(32, (index) => index)),
      plaintext: plaintext,
    );
    expect(sealed.nonce, hasLength(12));
    expect(sealed.protectedBytes, hasLength(plaintext.length + 16));
    expect(
      await primitive.decrypt(
        key: Uint8List.fromList(List<int>.generate(32, (index) => index)),
        nonce: sealed.nonce,
        protectedBytes: sealed.protectedBytes,
      ),
      plaintext,
    );

    // Fixed pre-migration v1 wire fixture: zero key/nonce, no AAD, JSON
    // plaintext, and ciphertext followed immediately by the 16-byte GCM tag.
    final legacyCipher = AesGcmCloudPayloadCipher(Uint8List(32));
    expect(
      await legacyCipher.decrypt(<String, Object?>{
        '_bil_cipher_v': 1,
        'alg': 'A256GCM',
        'nonce': base64Url.encode(Uint8List(12)),
        'ciphertext': base64Url.encode(
          _hex(
            'b5852c582a0108172574b1a1cf96e0'
            '5d03f5b4f73d7d504d0c8133d78db295',
          ),
        ),
      }),
      <String, Object?>{'legacy': true},
    );
  });

  testWidgets(
    'native secure account-key cache survives reopen and isolates owners',
    (tester) async {
      expect(Platform.isAndroid || Platform.isIOS, isTrue);
      // No initialized app/Auth/cloud and no real owner slots. Exercise the real
      // secure-storage plugin; only the unavailable canonical-key RPC is injected.
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final ownerA = 'bil-native-qa-a-$suffix';
      final ownerB = 'bil-native-qa-b-$suffix';
      var owner = ownerA;
      var rpcCalls = 0;
      final keyA = List<int>.generate(32, (index) => index + 10);
      final keyB = List<int>.generate(32, (index) => index + 70);
      final client = SupabaseClient(
        'http://127.0.0.1:1',
        'synthetic-native-qa',
      );
      final store = FlutterSecureCloudSecretStore();
      CloudAccountKeyRepository repository() => CloudAccountKeyRepository(
        client: client,
        secureStore: store,
        activeOwner: () => owner,
        rpc: (name) {
          expect(name, 'bil_get_or_create_cloud_key');
          rpcCalls++;
          return base64.encode(owner == ownerA ? keyA : keyB);
        },
      );

      // Independent teardown callbacks preserve the original test exception.
      // Cleanup errors still fail the test, and one delete cannot skip another.
      // Registered in reverse order because addTearDown executes last-in first.
      addTearDown(client.dispose);
      addTearDown(() => repository().removeLocal(ownerB));
      addTearDown(() => repository().removeLocal(ownerA));

      expect(await repository().readCached(ownerA), isNull);
      expect(await repository().resolve(ownerA), keyA);
      // A fresh repository and plugin wrapper read native persisted storage.
      expect(
        await CloudAccountKeyRepository(
          client: client,
          activeOwner: () => owner,
          rpc: (_) => throw StateError('Native cached key must not call cloud'),
        ).resolve(ownerA),
        keyA,
      );
      owner = ownerB;
      expect(await repository().resolve(ownerB), keyB);
      await expectLater(repository().readCached(ownerA), throwsStateError);
      owner = ownerA;
      expect(await repository().readCached(ownerA), keyA);
      expect(rpcCalls, 2);
      await repository().removeLocal(ownerA);
      expect(await repository().readCached(ownerA), isNull);
      owner = ownerB;
      expect(await repository().readCached(ownerB), keyB);
      owner = ownerA;
      await store.write(
        'bil.cloud.payload-key.v1.$ownerA',
        'corrupt-native-fixture',
      );
      await expectLater(repository().readCached(ownerA), throwsFormatException);
      expect(rpcCalls, 2, reason: 'Corruption must not silently create a key.');
    },
  );
}

Uint8List _hex(String value) {
  if (value.length.isOdd) {
    throw const FormatException('Hex input must contain complete bytes.');
  }
  return Uint8List.fromList(<int>[
    for (var offset = 0; offset < value.length; offset += 2)
      int.parse(value.substring(offset, offset + 2), radix: 16),
  ]);
}
