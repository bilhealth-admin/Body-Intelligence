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
      expect(source, contains('build_number:'), reason: path);
      expect(source, contains('required: true'), reason: path);
      expect(source, contains('--build-number "\$BUILD_NUMBER"'), reason: path);
      expect(source, contains('BIL-build-number.txt'), reason: path);
      expect(source, contains('CODE_GATE=PASS'), reason: path);
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
      expect(source, contains("os.environ['ASC_PRIVATE_KEY_BASE64']"));
      expect(source, contains(r'chmod 600 "$ASC_KEY_PATH"'));
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
