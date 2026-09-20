import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple preparation files and contracts are present', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    final appAttestBridge = File(
      'ios/Runner/BILAppAttestBridge.swift',
    ).readAsStringSync();
    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(project).length,
      greaterThanOrEqualTo(3),
    );
    expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(project, contains('InfoPlist.strings in Resources'));
    expect(privacy, contains('<key>NSPrivacyTracking</key><false/>'));
    expect(
      privacy,
      contains('NSPrivacyAccessedAPICategoryUserDefaults'),
      reason:
          'The one-time App Attest key-id migration reads app-owned defaults.',
    );
    expect(
      privacy,
      contains('<string>CA92.1</string>'),
      reason: 'App-only UserDefaults access must declare Apple reason CA92.1.',
    );
    expect(appAttestBridge, contains('import Security'));
    expect(appAttestBridge, contains('kSecClassGenericPassword'));
    expect(
      appAttestBridge,
      contains('kSecAttrSynchronizable as String: false'),
    );
    expect(
      appAttestBridge,
      contains('kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly'),
    );
    expect(appAttestBridge, contains('removeLegacyKeyId(for: accountId)'));
    expect(appAttestBridge, isNot(contains('private let keyMapDefaultsKey')));
    for (final locale in ['en', 'ar']) {
      final strings = File(
        'ios/Runner/$locale.lproj/InfoPlist.strings',
      ).readAsStringSync();
      for (final key in [
        'NSHealthShareUsageDescription',
        'NSHealthUpdateUsageDescription',
        'NSBluetoothAlwaysUsageDescription',
        'NSBluetoothPeripheralUsageDescription',
      ]) {
        expect(strings, contains('"$key"'));
      }
    }
  });
}
