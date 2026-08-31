import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
// ignore: depend_on_referenced_packages
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:gotrue/gotrue.dart';

void main() {
  test('release uses only mobile operating-system AES-GCM providers', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final lock = File('pubspec.lock').readAsStringSync();
    final packageConfig = File(
      '.dart_tool/package_config.json',
    ).readAsStringSync();
    final resolvedPackages =
        ((jsonDecode(packageConfig) as Map<String, Object?>)['packages']!
                as List<Object?>)
            .cast<Map<String, Object?>>();
    final resolvedPackageNames = resolvedPackages
        .map((entry) => entry['name']! as String)
        .toSet();
    final dartCipher = File(
      'lib/features/cloud_platform/services/aes_gcm_cloud_payload_cipher.dart',
    ).readAsStringSync();
    final android = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/'
      'BILSystemCryptoBridge.kt',
    ).readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/'
      'MainActivity.kt',
    ).readAsStringSync();
    final ios = File(
      'ios/Runner/BILSystemCryptoBridge.swift',
    ).readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final jwtShim = File(
      'tool/vendor_dart_jsonwebtoken/lib/dart_jsonwebtoken.dart',
    ).readAsStringSync();
    final archiveForkSources = Directory('tool/vendor_archive/lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(pubspec, isNot(contains('pointycastle:')));
    expect(pubspec, isNot(contains('cryptography:')));
    expect(pubspec, isNot(contains('\n  encrypt:')));
    expect(lock, isNot(contains('\n  pointycastle:')));
    expect(lock, isNot(contains('\n  cryptography:')));
    expect(lock, isNot(contains('\n  encrypt:')));
    expect(lock, contains('tool/vendor_archive'));
    expect(lock, contains('tool/vendor_dart_jsonwebtoken'));
    expect(packageConfig, contains('../tool/vendor_archive'));
    expect(packageConfig, contains('../tool/vendor_dart_jsonwebtoken'));
    expect(resolvedPackageNames, isNot(contains('pointycastle')));
    expect(resolvedPackageNames, isNot(contains('cryptography')));
    expect(resolvedPackageNames, isNot(contains('encrypt')));
    expect(dartCipher, isNot(contains('package:pointycastle')));
    expect(dartCipher, contains("MethodChannel('bil/system_crypto')"));
    expect(android, contains('Cipher.getInstance(TRANSFORMATION)'));
    expect(android, contains('AES/GCM/NoPadding'));
    expect(android, contains('GCMParameterSpec(TAG_LENGTH_BITS, nonce)'));
    expect(mainActivity, contains('BILSystemCryptoBridge('));
    expect(ios, contains('import CryptoKit'));
    expect(ios, contains('AES.GCM.seal'));
    expect(ios, contains('AES.GCM.open'));
    expect(appDelegate, contains('BILSystemCryptoBridge.register('));
    expect(project, contains('BILSystemCryptoBridge.swift in Sources'));
    expect(jwtShim, isNot(contains('pointycastle')));
    expect(jwtShim, contains('throw UnsupportedError'));
    expect(
      File('tool/vendor_archive/lib/src/util/aes.dart').existsSync(),
      isFalse,
    );
    expect(
      File('tool/vendor_archive/lib/src/util/aes_decrypt.dart').existsSync(),
      isFalse,
    );
    expect(
      File('tool/vendor_archive/lib/src/util/encryption.dart').existsSync(),
      isFalse,
    );
    expect(archiveForkSources, isNot(contains('PcAESEngine')));
    expect(archiveForkSources, isNot(contains('PcPBKDF')));
    expect(archiveForkSources, isNot(contains('PcHMac')));
    expect(archiveForkSources, isNot(contains('PBKDF2KeyDerivator')));
    expect(archiveForkSources, isNot(contains('ZipCrypto')));
    expect(archiveForkSources, isNot(contains('GCMBlockCipher')));
    expect(archiveForkSources, isNot(contains('package:pointycastle')));
    expect(archiveForkSources, isNot(contains('package:cryptography')));
    expect(archiveForkSources, isNot(contains('package:encrypt/')));
    expect(archiveForkSources, contains('Encrypted ZIP archives are disabled'));
    expect(
      info,
      contains('<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>'),
    );
  });

  test('application never invokes disabled local JWT verification', () {
    final applicationSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(applicationSources, isNot(contains('.getClaims(')));
    expect(applicationSources, isNot(contains('JWT.verify(')));
    expect(applicationSources, isNot(contains('package:dart_jsonwebtoken')));
    expect(applicationSources, isNot(contains('package:pointycastle')));
    expect(applicationSources, isNot(contains('package:cryptography')));
    expect(applicationSources, isNot(contains('package:encrypt/')));
  });

  test('local JWT compatibility surface always fails closed', () {
    final key = RSAPublicKey.bytes(Uint8List.fromList(<int>[1]));

    expect(
      () => JWT.verify('header.payload.signature', key),
      throwsUnsupportedError,
    );
    expect(JWT.tryVerify('header.payload.signature', key), isNull);
  });

  test(
    'Supabase session recovery does not need local JWT verification',
    () async {
      String encodePart(Map<String, Object> value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

      final userId = '00000000-0000-4000-8000-000000000001';
      final accessToken = <String>[
        encodePart(<String, Object>{'alg': 'HS256', 'typ': 'JWT'}),
        encodePart(<String, Object>{
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          'sub': userId,
        }),
        'not-a-signature',
      ].join('.');
      final client = GoTrueClient(autoRefreshToken: false);

      try {
        final response = await client.recoverSession(
          jsonEncode(<String, Object>{
            'access_token': accessToken,
            'expires_in': 3600,
            'refresh_token': 'local-test-refresh-token',
            'token_type': 'bearer',
            'user': <String, Object>{
              'id': userId,
              'app_metadata': <String, Object>{},
              'user_metadata': <String, Object>{},
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00.000Z',
            },
          }),
        );

        expect(response.session?.user.id, userId);
        expect(client.currentSession?.user.id, userId);
        expect(client.currentUser?.id, userId);
      } finally {
        client.dispose();
      }
    },
  );

  test('crypto-free archive fork preserves unencrypted ZIP reports', () {
    final source = Archive()
      ..addFile(ArchiveFile.string('report.txt', 'BIL report'));
    final encoded = ZipEncoder().encodeBytes(source);
    final decoded = ZipDecoder().decodeBytes(encoded, verify: true);

    expect(decoded.files.single.name, 'report.txt');
    expect(
      utf8.decode(decoded.files.single.content as List<int>),
      'BIL report',
    );
  });

  test('crypto-free archive fork rejects all encrypted-code paths', () {
    expect(
      () => ZipEncoder(password: 'not-used-by-bil'),
      throwsUnsupportedError,
    );
    expect(
      () => XZEncoder().encodeBytes(<int>[1], check: XZCheck.sha256),
      throwsUnsupportedError,
    );

    final source = Archive()
      ..addFile(ArchiveFile.string('report.txt', 'BIL report'));
    final encoded = ZipEncoder().encodeBytes(source);
    encoded[6] |= 0x01;
    expect(() => ZipDecoder().decodeBytes(encoded), throwsUnsupportedError);
  });

  test('legacy v1 cloud envelope remains explicitly supported', () {
    final source = File(
      'lib/features/cloud_platform/services/aes_gcm_cloud_payload_cipher.dart',
    ).readAsStringSync();
    expect(source, contains('static const _version = 1;'));
    expect(source, contains("static const _algorithm = 'A256GCM';"));
    expect(source, contains('static const _nonceLength = 12;'));
    expect(source, contains('static const _tagLength = 16;'));
  });
}
