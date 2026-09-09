import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('platform build identity is exact while candidate is not accepted', () {
    final pubspec = read('pubspec.yaml');
    final android = read('android/app/build.gradle.kts');
    final apple = read('ios/Runner.xcodeproj/project.pbxproj');
    final gate = read('docs/launch_readiness/BIL_RELEASE_CANDIDATE_GATE.md');
    final androidWorkflow = read(
      '.github/workflows/bil_android_release_candidate.yml',
    );
    final iosWorkflow = read('.github/workflows/bil_ios_signed_release.yml');

    expect(pubspec, contains('version: 1.0.0+8'));
    expect(
      android,
      contains('applicationId = "com.bilhealth.bodyintelligencelog"'),
    );
    expect(android, contains('versionCode = flutter.versionCode'));
    expect(android, contains('versionName = flutter.versionName'));
    expect(
      apple,
      contains(
        'PRODUCT_BUNDLE_IDENTIFIER = com.bilhealth.bodyintelligencelog;',
      ),
    );
    expect(gate, contains('CURRENT_PLUS8_CANDIDATE_ACCEPTED: FALSE'));
    expect(gate, isNot(contains('## Accepted parent')));
    expect(androidWorkflow, contains('(( BUILD_NUMBER == 9 ))'));
    expect(iosWorkflow, contains('(( BUILD_NUMBER == 11 ))'));
    expect(iosWorkflow, isNot(contains('(( BUILD_NUMBER == 9 ))')));
    expect(androidWorkflow, contains('build 8 must never be promoted'));
    expect(
      iosWorkflow,
      contains(r'--build-number "$BUILD_NUMBER"'),
      reason: 'iOS must override pubspec +8 with the signed release build 11.',
    );
    expect(
      iosWorkflow,
      contains('BIL_IOS_V11_FROZEN_SOURCE_MANIFEST_2026-09-09.md'),
    );
    expect(iosWorkflow, contains('BIL_IOS_V11_AUDITED_SOURCE_SHA'));
    expect(iosWorkflow, contains('BIL_IOS_V11_STAGING_MANIFEST_SHA256'));
  });

  test('all accepted launch boundaries remain present', () {
    final boundaries = <String, String>{
      'docs/launch_readiness/BIL_GLOBAL_LAUNCH_BOUNDARY.md':
          'BIL-V1-LAUNCH-006',
      'docs/launch_readiness/BIL_ANDROID_RELEASE_BOUNDARY.md':
          'com.bilhealth.bodyintelligencelog',
      'docs/launch_readiness/BIL_APPLE_RELEASE_BOUNDARY.md': 'HealthKit',
      'docs/launch_readiness/BIL_STORE_PRIVACY_EVIDENCE.md': 'External gates',
      'docs/ARCHITECTURE.md': 'Architecture',
      'docs/architecture/BIL_DASHBOARD_EPIC_CLOSURE.md': 'Dashboard',
      'docs/architecture/BIL_TRUTH_EPIC_CLOSURE.md': 'Truth',
      'docs/architecture/BIL_PREMIUM_UI_EPIC_CLOSURE.md': 'Premium UI',
    };

    for (final entry in boundaries.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: 'Missing ${entry.key}');
      expect(read(entry.key), contains(entry.value), reason: entry.key);
    }
  });

  test('release candidate gate distinguishes build from public launch', () {
    final gate = read('docs/launch_readiness/BIL_RELEASE_CANDIDATE_GATE.md');

    expect(gate, contains('complete Flutter test suite'));
    expect(gate, contains('SHA-256'));
    expect(gate, contains('not an authorized upload artifact'));
    expect(gate, contains('Passing this gate does not claim public launch'));
  });

  test('owner runtime waiver preserves source and signed-artifact gates', () {
    final gate = read('docs/launch_readiness/BIL_RELEASE_CANDIDATE_GATE.md');
    expect(gate, contains('NOT_RUN_OWNER_WAIVED'));
    expect(gate, contains('exclusions are not passes'));
    expect(gate, contains('tool/release/run_portable_release_tests.py'));
    expect(gate, contains('signing, entitlements, and store requirements'));
    expect(
      gate,
      isNot(contains('four platform/form-factor\nruntime reports exist')),
    );
    expect(gate, contains('Source-only freeze acceptance'));
    expect(gate, contains('actual signed-artifact verification'));
  });
}
