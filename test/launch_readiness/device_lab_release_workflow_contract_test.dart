import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('signed release workflows pin toolchain and require build identity', () {
    for (final path in <String>[
      '.github/workflows/bil_android_release_candidate.yml',
      '.github/workflows/bil_ios_signed_release.yml',
    ]) {
      final source = _read(path);
      expect(source, contains('flutter-version: 3.44.6'), reason: path);
      expect(source, contains('expected_source_sha:'), reason: path);
      expect(source, contains('qa_run_ids:'), reason: path);
      expect(source, contains('required: true'), reason: path);
      expect(source, contains('--build-number "\$BUILD_NUMBER"'), reason: path);
      expect(source, contains('BIL-build-number.txt'), reason: path);
      expect(
        source,
        contains(
          path.contains('ios')
              ? 'CODE_GATE=SIGNED_IPA_ARTIFACT_ONLY'
              : 'CODE_GATE=PASS',
        ),
        reason: path,
      );
      expect(source, contains('PHYSICAL_DEVICE_GATE=REQUIRED'), reason: path);
    }
  });

  test('Android candidate verifies the exact upload certificate', () {
    final source = _read('.github/workflows/bil_android_release_candidate.yml');
    expect(source, contains('ANDROID_UPLOAD_CERTIFICATE_SHA256'));
    expect(source, contains('keytool -printcert -rfc -jarfile'));
    expect(source, contains('openssl x509 -noout -fingerprint -sha256'));
    expect(source, contains('ANDROID_UPLOAD_CERTIFICATE_SHA256=MATCH'));
  });

  test('Android native crypto runtime gate cannot be waived', () {
    final source = _read('.github/workflows/bil_android_release_candidate.yml');
    expect(source, isNot(contains('run_native_crypto_checks:')));
    expect(
      source,
      contains('integration_test/system_crypto_bridge_integration_test.dart'),
    );
    expect(source, contains('reactivecircus/android-emulator-runner@'));
    expect(source, contains("NATIVE_CRYPTO_GATE_STATUS='PASS'"));
    expect(source, isNot(contains('NOT_RUN_OWNER_WAIVED')));
    expect(
      source,
      contains('"NATIVE_CRYPTO_GATE=\$NATIVE_CRYPTO_GATE_STATUS"'),
    );
    expect(source, isNot(contains("'NATIVE_CRYPTO_GATE=PASS'")));
    expect(source, contains('PHYSICAL_DEVICE_GATE=REQUIRED'));
  });

  test(
    'iOS candidate fails closed on team profile and signed entitlements',
    () {
      final source = _read('.github/workflows/bil_ios_signed_release.yml');
      expect(source, contains('Xcode DEVELOPMENT_TEAM does not match'));
      expect(source, isNot(contains("sed -i ''")));
      expect(source, isNot(contains('base64 --decode')));
      expect(
        source,
        contains(
          "base64.b64decode(os.environ['PROFILE_BASE64'], validate=True)",
        ),
      );
      // Upload credentials belong only to the separately dispatched promotion.
      expect(source, isNot(contains('APP_STORE_CONNECT_PRIVATE_KEY_BASE64')));
      final promotion = _read(
        '.github/workflows/bil_ios_upload_existing_testflight.yml',
      );
      expect(promotion, contains("os.environ['ASC_PRIVATE_KEY_BASE64']"));
      expect(promotion, contains('key.chmod(0o600)'));
      expect(
        source,
        contains("entitlements.get('com.apple.developer.healthkit')"),
      );
      expect(
        source,
        contains("entitlements.get('com.apple.developer.applesignin'"),
      );
      expect(source, contains("entitlements.get('aps-environment')"));
      expect(source, contains("entitlements.get('get-task-allow', False)"));
      expect(source, contains("profile.get('ExpirationDate')"));
    },
  );

  test('HealthKit simulator cannot claim the physical-device gate', () {
    final source = _read('.github/workflows/bil_healthkit_cloud_simulator.yml');
    expect(source, contains('flutter-version: 3.44.6'));
    expect(source, contains("job.status == 'success'"));
    expect(source, contains('CODE_GATE=\$CODE_GATE_STATUS'));
    expect(source, contains('SIMULATOR_GATE=EVIDENCE_ONLY'));
    expect(source, contains('PHYSICAL_DEVICE_GATE=REQUIRED'));
    expect(source, contains('PHYSICAL_DEVICE_REQUIRED.txt'));
  });
}
