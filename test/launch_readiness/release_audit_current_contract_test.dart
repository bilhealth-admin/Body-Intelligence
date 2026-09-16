import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/epic14_release_audit.dart' as release_audit;

String read(String path) => File(path).readAsStringSync();

void main() {
  test('Epic 14 permits development push but rejects production in Debug', () {
    const key = '<key>aps-environment</key>';
    for (final allowed in [
      '<dict/>',
      '<dict>$key<string>development</string></dict>',
    ]) {
      expect(release_audit.debugPushEnvironmentIsValid(allowed), isTrue);
    }
    for (final forbidden in [
      '<dict>$key<string>production</string></dict>',
      '<dict>$key<true/></dict>',
      '<dict>$key<string>unexpected</string></dict>',
      '<dict>$key<string>development</string>$key<string>production</string></dict>',
    ]) {
      expect(release_audit.debugPushEnvironmentIsValid(forbidden), isFalse);
    }
  });

  test('Epic 14 audits the Android plugin version used by this release', () {
    final settings = read('android/settings.gradle.kts');
    final pluginVersion = RegExp(
      r'id\("com\.android\.application"\) version "([^"]+)"',
    ).firstMatch(settings)?.group(1);
    expect(pluginVersion, isNotNull);
    expect(
      read('tool/epic14_release_audit.dart'),
      contains('com.android.application") version "$pluginVersion"'),
    );
  });

  test('Epic 14 and Epic 16 audits derive the current release version', () {
    final pubspec = read('pubspec.yaml');
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)\s*(?:#.*)?$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull);
    final version = match!.group(1)!;
    final candidateGate = read(
      'docs/launch_readiness/BIL_RELEASE_CANDIDATE_GATE.md',
    );
    expect(candidateGate, contains('Version metadata: `$version`'));

    for (final path in <String>[
      'tool/epic14_release_audit.dart',
      'tool/epic16_release_audit.dart',
    ]) {
      final audit = read(path);
      expect(audit, contains('_releaseVersion(pubspec)'), reason: path);
      expect(audit, contains('BIL_RELEASE_CANDIDATE_GATE.md'), reason: path);
      expect(audit, isNot(contains('version: 1.0.0+1')), reason: path);
    }
  });

  test('Epic 14 allows only the reviewed Android activity scope', () {
    final audit = read('tool/epic14_release_audit.dart');
    for (final permission in <String>[
      'READ_STEPS',
      'READ_DISTANCE',
      'READ_ACTIVE_CALORIES_BURNED',
    ]) {
      expect(audit, contains("'$permission'"), reason: permission);
    }
    for (final permission in <String>[
      'READ_EXERCISE',
      'READ_SLEEP',
      'READ_HEART_RATE',
      'READ_RESTING_HEART_RATE',
      'READ_HEART_RATE_VARIABILITY',
      'READ_WEIGHT',
      'WRITE_WEIGHT',
      'READ_NUTRITION',
      'WRITE_NUTRITION',
      'READ_BLOOD_PRESSURE',
      'READ_OXYGEN_SATURATION',
      'READ_BLOOD_GLUCOSE',
      'READ_BODY_TEMPERATURE',
    ]) {
      expect(audit, isNot(contains("'$permission'")), reason: permission);
    }
    expect(audit, contains('!allowedHealthPermissions.contains(permission)'));
  });

  test('Epic 16 audit follows the current fail-closed ad policy states', () {
    final audit = read('tool/epic16_release_audit.dart');
    for (final state in <String>[
      'paidSubscription',
      'entitlementUnverified',
      'sensitiveContext',
      'providerUnavailable',
      'offline',
      'ageUnknown',
      'underage',
      'allowed',
    ]) {
      expect(audit, contains("'$state'"), reason: state);
    }
    expect(audit, isNot(contains("'consentMissing'")));
    expect(audit, isNot(contains("'contextualOnly'")));
    expect(audit, contains('lib/app/services/data_export_service.dart'));
    expect(audit, contains('SharePlus.instance.share'));
    expect(audit, contains('!dataExport.contains(\'Clipboard\')'));
  });
}
