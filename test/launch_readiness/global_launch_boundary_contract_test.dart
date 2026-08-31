import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('launch phase has one authorized parent and bounded sequence', () {
    final boundary = _compact(
      File(
        'docs/launch_readiness/BIL_GLOBAL_LAUNCH_BOUNDARY.md',
      ).readAsStringSync(),
    );
    final nextPackages = _compact(
      File('docs/NEXT_PACKAGES.md').readAsStringSync(),
    );

    expect(boundary, contains('BIL V1 Global Launch Readiness'));
    expect(boundary, contains('9fe26c3ceddf6e1d1de6bcb04344da043f3bb338'));
    for (var package = 1; package <= 6; package++) {
      final id = package.toString().padLeft(3, '0');
      expect(nextPackages, contains('BIL-V1-LAUNCH-$id'));
    }
  });

  test('repository audit matches tracked platform configuration', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();

    expect(pubspec, contains('version: 1.0.0+5'));
    expect(
      gradle,
      contains('applicationId = "com.bilhealth.bodyintelligencelog"'),
    );
    expect(gradle, contains('minSdk = 26'));
    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, contains('signingConfig = if (hasReleaseSigning)'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(
      project,
      contains(
        'PRODUCT_BUNDLE_IDENTIFIER = com.bilhealth.bodyintelligencelog;',
      ),
    );
    expect(project, contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'));
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(info, contains('NSHealthShareUsageDescription'));
    expect(info, contains('NSBluetoothAlwaysUsageDescription'));
  });

  test('external gates remain explicit and secrets remain excluded', () {
    final boundary = _compact(
      File(
        'docs/launch_readiness/BIL_GLOBAL_LAUNCH_BOUNDARY.md',
      ).readAsStringSync(),
    );

    for (final gate in <String>[
      'credentials',
      'keystores',
      'certificates',
      'Google Play',
      'App Store Connect',
      'legal declarations',
      'physical-device certification',
      'store approval',
    ]) {
      expect(boundary, contains(gate), reason: 'Missing gate: $gate');
    }
  });
}
