import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple identity deployment and capability are release bounded', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();

    expect(project, contains('PRODUCT_BUNDLE_IDENTIFIER = com.kadem.bil;'));
    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(project).length,
      greaterThanOrEqualTo(3),
    );
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    );
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(entitlements, contains('com.apple.developer.healthkit'));
    expect(
      entitlements,
      isNot(contains('com.apple.developer.team-identifier')),
    );
  });

  test('Apple privacy manifest and consent copy are explicit', () {
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();

    expect(privacy, contains('<key>NSPrivacyTracking</key><false/>'));
    expect(privacy, contains('<key>NSPrivacyTrackingDomains</key><array/>'));
    expect(privacy, contains('<key>NSPrivacyCollectedDataTypes</key><array/>'));

    for (final key in <String>[
      'NSHealthShareUsageDescription',
      'NSHealthUpdateUsageDescription',
      'NSBluetoothAlwaysUsageDescription',
      'NSBluetoothPeripheralUsageDescription',
    ]) {
      expect(info, contains('<key>$key</key>'));
      for (final locale in <String>['en', 'ar']) {
        final localized = File(
          'ios/Runner/$locale.lproj/InfoPlist.strings',
        ).readAsStringSync();
        expect(localized, contains('"$key"'), reason: '$locale missing $key');
      }
    }
  });

  test('HealthKit writes are restricted to weight and hydration', () {
    final bridge = File(
      'ios/Runner/BILGlobalHealthBridge.swift',
    ).readAsStringSync();
    final writeBoundary = RegExp(
      r'private func canWrite\(_ type: HKSampleType\) -> Bool \{([\s\S]*?)\n  \}',
    ).firstMatch(bridge)?.group(1);

    expect(writeBoundary, isNotNull);
    expect(writeBoundary, contains('.bodyMass'));
    expect(writeBoundary, contains('.dietaryWater'));
    for (final prohibited in <String>[
      '.stepCount',
      '.activeEnergyBurned',
      '.heartRate',
      '.bloodGlucose',
      '.bloodPressureSystolic',
      '.dietaryEnergyConsumed',
    ]) {
      expect(
        writeBoundary,
        isNot(contains(prohibited)),
        reason: 'Unexpected writable HealthKit type: $prohibited',
      );
    }
    expect(bridge, contains('let writeTypes: Set<HKSampleType>'));
    expect(
      bridge,
      contains('writeRequested ? readTypes.filter(canWrite) : []'),
    );
    expect(bridge, contains('canWrite(type)'));
  });

  test('Apple readiness documentation matches the production project', () {
    final readiness = File('docs/IOS_READINESS.md').readAsStringSync();
    final boundary = File(
      'docs/launch_readiness/BIL_APPLE_RELEASE_BOUNDARY.md',
    ).readAsStringSync();

    expect(readiness, contains('`com.kadem.bil`'));
    expect(readiness, contains('HealthKit write access is limited'));
    expect(readiness, isNot(contains('com.example.bodyIntelligenceLog')));
    expect(readiness, isNot(contains('MVP does not use')));
    expect(boundary, contains('71426e6fd60f3e517c3866c8acd22c1470c8d53d'));
    expect(boundary, contains('External gates'));
  });
}
