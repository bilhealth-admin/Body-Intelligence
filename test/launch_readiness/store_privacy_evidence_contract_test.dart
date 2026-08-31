import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('local-first release capabilities remain inactive by default', () {
    final environment = read('lib/app/environment/app_environment.dart');
    final capabilities = read('lib/app/services/external_capabilities.dart');
    final pubspec = read('pubspec.yaml');

    expect(environment, contains("'BIL_USE_SUPABASE'"));
    expect(environment, contains('defaultValue: false'));
    expect(capabilities, contains('ExternalCapability.sync'));
    expect(capabilities, contains('available: false'));
    expect(
      capabilities,
      contains('Local Mode is active. No data is uploaded.'),
    );

    for (final dependency in <String>[
      'firebase_analytics:',
      'firebase_crashlytics:',
      'sentry_flutter:',
      'appsflyer_sdk:',
      'amplitude_flutter:',
    ]) {
      expect(pubspec, isNot(contains(dependency)), reason: dependency);
    }
    expect(pubspec, contains('in_app_purchase:'));
    expect(environment, contains("'BIL_PAYMENTS_ENABLED'"));
    expect(environment, contains('paymentsEnabled'));
    expect(capabilities, contains('ExternalCapability.commerce'));
    expect(
      capabilities,
      contains('verified receipt/webhook activation is pending'),
    );
  });

  test('platform health privacy boundaries match store drafts', () {
    final android = read('android/app/src/main/AndroidManifest.xml');
    final applePrivacy = read('ios/Runner/PrivacyInfo.xcprivacy');
    final appleBridge = read('ios/Runner/BILGlobalHealthBridge.swift');

    expect(android, contains('android.permission.health.WRITE_WEIGHT'));
    expect(android, isNot(contains('WRITE_HYDRATION')));
    expect(android, contains('WRITE_NUTRITION'));
    expect(android, contains('ACTION_SHOW_PERMISSIONS_RATIONALE'));

    expect(applePrivacy, contains('<key>NSPrivacyTracking</key><false/>'));
    expect(
      applePrivacy,
      contains('<key>NSPrivacyTrackingDomains</key><array/>'),
    );
    expect(appleBridge, contains('.bodyMass'));
    for (final type in <String>[
      'steps',
      'distance',
      'activeEnergy',
      'workout',
      'sleep',
      'heartRate',
      'nutritionProtein',
      'nutritionCarbohydrates',
      'nutritionFat',
    ]) {
      expect(appleBridge, contains('"$type"'));
    }
    for (final removedType in <String>[
      'bloodPressureSystolic',
      'bloodPressureDiastolic',
      'oxygen',
    ]) {
      expect(appleBridge, isNot(contains('"$removedType"')));
    }
  });

  test('store drafts separate repository evidence from submission claims', () {
    final dataSafety = read(
      'docs/google_play_preparation/DATA_SAFETY_DRAFT.md',
    );
    final health = read(
      'docs/google_play_preparation/HEALTH_APPS_DECLARATION_DRAFT.md',
    );
    final appPrivacy = read('docs/apple_preparation/APP_PRIVACY_DRAFT.md');
    final policy = read('docs/apple_preparation/PRIVACY_POLICY_DRAFT.md');
    final evidence = read(
      'docs/launch_readiness/BIL_STORE_PRIVACY_EVIDENCE.md',
    );

    for (final draft in <String>[dataSafety, health, appPrivacy]) {
      expect(draft.toUpperCase(), contains('DO NOT SUBMIT'));
    }
    expect(policy, contains('[REQUIRED]'));
    expect(policy, contains('[REQUIRED HTTPS URL]'));
    expect(evidence, contains('70280d05eedad635be1c427c41ffaad18337e65c'));
    expect(evidence, contains('External gates'));
    expect(evidence, contains('Product Owner'));
  });
}
