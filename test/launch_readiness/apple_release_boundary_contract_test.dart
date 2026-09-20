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
    final debugEntitlements = File(
      'ios/Runner/RunnerDebug.entitlements',
    ).readAsStringSync();

    expect(
      project,
      contains(
        'PRODUCT_BUNDLE_IDENTIFIER = com.bilhealth.bodyintelligencelog;',
      ),
    );
    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(project).length,
      greaterThanOrEqualTo(3),
    );
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    );
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    for (final signingEntitlements in <String>[
      entitlements,
      debugEntitlements,
    ]) {
      expect(
        signingEntitlements,
        contains('com.apple.developer.applesignin'),
        reason: 'Sign in with Apple must be present in every signed build.',
      );
      expect(signingEntitlements, contains('<string>Default</string>'));
    }
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
    expect(privacy, contains('<key>NSPrivacyCollectedDataTypes</key>'));
    for (final dataType in <String>[
      'NSPrivacyCollectedDataTypeName',
      'NSPrivacyCollectedDataTypeEmailAddress',
      'NSPrivacyCollectedDataTypePhoneNumber',
      'NSPrivacyCollectedDataTypeHealth',
      'NSPrivacyCollectedDataTypeFitness',
      'NSPrivacyCollectedDataTypeUserID',
      'NSPrivacyCollectedDataTypeDeviceID',
      'NSPrivacyCollectedDataTypeOtherUserContent',
      'NSPrivacyCollectedDataTypeEmailsOrTextMessages',
      'NSPrivacyCollectedDataTypePhotosorVideos',
      'NSPrivacyCollectedDataTypePurchaseHistory',
      'NSPrivacyCollectedDataTypeProductInteraction',
    ]) {
      expect(privacy, contains('<string>$dataType</string>'));
    }
    String declarationFor(String dataType) {
      return RegExp(
            '<dict>(?:(?!<dict>).)*<string>$dataType</string>.*?</dict>',
            dotAll: true,
          ).firstMatch(privacy)?.group(0) ??
          '';
    }

    final nameDeclaration = declarationFor('NSPrivacyCollectedDataTypeName');
    expect(
      nameDeclaration,
      contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'),
    );
    expect(
      nameDeclaration,
      contains('NSPrivacyCollectedDataTypePurposeProductPersonalization'),
    );

    final productInteractionDeclaration = declarationFor(
      'NSPrivacyCollectedDataTypeProductInteraction',
    );
    expect(
      RegExp(
        '<key>NSPrivacyCollectedDataTypeLinked</key>\\s*<true/>',
      ).hasMatch(productInteractionDeclaration),
      isTrue,
    );
    expect(
      RegExp(
        '<key>NSPrivacyCollectedDataTypeTracking</key>\\s*<false/>',
      ).hasMatch(productInteractionDeclaration),
      isTrue,
    );
    expect(
      productInteractionDeclaration,
      contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'),
    );
    expect(
      privacy,
      isNot(contains('NSPrivacyCollectedDataTypeAudioData')),
      reason: 'The current client uploads recognized text, not raw audio.',
    );

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
    expect(
      info,
      matches(RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>')),
      reason:
          'The iOS client delegates AES-256-GCM to Apple CryptoKit and ships no non-exempt cipher implementation.',
    );
  });

  test('Apple collected-data declarations follow current cloud boundaries', () {
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    final deviceIdentity = File(
      'lib/features/cloud_platform/services/cloud_device_identity_repository.dart',
    ).readAsStringSync();
    final cloudTransport = File(
      'lib/features/cloud_platform/services/supabase_cloud_transport.dart',
    ).readAsStringSync();
    final community = File(
      'lib/features/community/data/community_repository.dart',
    ).readAsStringSync();
    final auth = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();
    final purchase = File(
      'lib/features/commerce/services/verified_store_purchase_service.dart',
    ).readAsStringSync();
    final voice = File(
      'lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart',
    ).readAsStringSync();
    final gateway = File(
      'lib/features/intelligence_center/services/local_model_gateway_io.dart',
    ).readAsStringSync();
    final coachContext = File(
      'lib/features/intelligence_center/services/coach_context_provider.dart',
    ).readAsStringSync();
    final aiUsage = File(
      'supabase/migrations/202608110004_bil_ai_coach_weekly_usage_and_boost.sql',
    ).readAsStringSync();

    expect(deviceIdentity, contains('_uuid.v4()'));
    expect(deviceIdentity, contains("'bil.cloud.device-id.v1'"));
    expect(cloudTransport, contains("'p_device_id': deviceId"));
    expect(community, contains(".from('bil_messages').insert"));
    expect(community, contains("'body': text"));
    expect(auth, contains("'phone': phone"));
    expect(purchase, contains("'verification_data':"));
    expect(purchase, contains('serverVerificationData'));
    expect(voice, contains('textOverride: transcript'));
    expect(gateway, isNot(contains("'audio':")));
    expect(gateway, isNot(contains("'audio_data':")));
    expect(coachContext, contains("'displayName': displayName"));
    expect(
      aiUsage,
      contains('create table if not exists public.bil_ai_usage_events'),
    );
    expect(
      aiUsage,
      contains('owner_id uuid not null references auth.users(id)'),
    );
    expect(privacy, isNot(contains('NSPrivacyCollectedDataTypeAudioData')));
  });

  test('HealthKit writes are restricted to reviewed weight records', () {
    final bridge = File(
      'ios/Runner/BILGlobalHealthBridge.swift',
    ).readAsStringSync();
    final writeBoundary = RegExp(
      r'private func canWrite\(_ type: HKSampleType\) -> Bool \{([\s\S]*?)\n  \}',
    ).firstMatch(bridge)?.group(1);

    expect(writeBoundary, isNotNull);
    expect(writeBoundary, contains('.bodyMass'));
    expect(writeBoundary, isNot(contains('.dietaryWater')));
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

  test(
    'HealthKit read scope is fitness-only and has no background delivery',
    () {
      final bridge = File(
        'ios/Runner/BILGlobalHealthBridge.swift',
      ).readAsStringSync();
      final entitlements = <String>[
        File('ios/Runner/Runner.entitlements').readAsStringSync(),
        File('ios/Runner/RunnerDebug.entitlements').readAsStringSync(),
      ];

      for (final retained in <String>[
        '.stepCount',
        '.distanceWalkingRunning',
        '.activeEnergyBurned',
        '.sleepAnalysis',
        '.bodyMass',
        '.bodyFatPercentage',
        '.leanBodyMass',
        '.heartRate',
        '.restingHeartRate',
        '.heartRateVariabilitySDNN',
        '.dietaryWater',
        '.dietaryEnergyConsumed',
      ]) {
        expect(
          bridge,
          contains(retained),
          reason: 'Missing fitness type $retained',
        );
      }
      for (final removed in <String>[
        '.oxygenSaturation',
        '.respiratoryRate',
        '.bloodGlucose',
        '.bloodPressureSystolic',
        '.bloodPressureDiastolic',
      ]) {
        expect(
          bridge,
          isNot(contains(removed)),
          reason: 'Medical/background API remains: $removed',
        );
      }
      expect(bridge, contains('case "enableBackgroundDelivery"'));
      expect(bridge, contains('foreground-refresh-only'));
      for (final entitlement in entitlements) {
        expect(entitlement, isNot(contains('healthkit.background-delivery')));
      }
    },
  );

  test('Apple readiness documentation matches the production project', () {
    final readiness = File('docs/IOS_READINESS.md').readAsStringSync();
    final boundary = File(
      'docs/launch_readiness/BIL_APPLE_RELEASE_BOUNDARY.md',
    ).readAsStringSync();

    expect(readiness, contains('`com.bilhealth.bodyintelligencelog`'));
    expect(readiness, contains('HealthKit write access is limited'));
    expect(readiness, isNot(contains('com.example.bodyIntelligenceLog')));
    expect(readiness, isNot(contains('MVP does not use')));
    expect(boundary, contains('71426e6fd60f3e517c3866c8acd22c1470c8d53d'));
    expect(boundary, contains('External gates'));
  });
}
