import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('release candidate identity and version are frozen', () {
    final pubspec = read('pubspec.yaml');
    final android = read('android/app/build.gradle.kts');
    final apple = read('ios/Runner.xcodeproj/project.pbxproj');
    final gate = read('docs/launch_readiness/BIL_RELEASE_CANDIDATE_GATE.md');

    expect(pubspec, contains('version: 1.0.0+3'));
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
    expect(gate, contains('71bea9c806b08a1dd40df6a342fc46afe6b7d565'));
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
}
