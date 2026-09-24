import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_apple_ai_privacy.dart';
import 'package:flutter_test/flutter_test.dart';

String _declarationFor(String manifest, String dataType) {
  final token = '<string>$dataType</string>';
  final tokenIndex = manifest.indexOf(token);
  if (tokenIndex < 0) return '';
  final start = manifest.lastIndexOf('<dict>', tokenIndex);
  final end = manifest.indexOf('</dict>', tokenIndex);
  if (start < 0 || end < 0) return '';
  return manifest.substring(start, end + '</dict>'.length);
}

String _librarySource(String path) {
  final library = File(path);
  final entrypoint = library.readAsStringSync();
  final parts = RegExp(r"part '([^']+)';")
      .allMatches(entrypoint)
      .map((match) => File('${library.parent.path}/${match.group(1)!}'));
  return <String>[
    entrypoint,
    for (final part in parts) part.readAsStringSync(),
  ].join('\n');
}

void main() {
  test('Apple AI consent copy is complete across all 25 locales', () {
    expect(AppleAiPrivacyRuntimeCopy.supported, RuntimeCopy.supported);
    for (final entry in AppleAiPrivacyRuntimeCopy.values.entries) {
      expect(
        entry.value.keys.toSet(),
        RuntimeCopy.supported,
        reason: entry.key,
      );
      for (final locale in RuntimeCopy.supported) {
        final localized = RuntimeCopy.resolve(entry.key, locale);
        expect(localized, isNotNull, reason: '$locale: ${entry.key}');
        expect(localized!.trim(), isNotEmpty, reason: '$locale: ${entry.key}');
      }
    }
  });

  test('Apple privacy manifest matches the current linked-data boundary', () {
    final manifest = File(
      'ios/Runner/PrivacyInfo.xcprivacy',
    ).readAsStringSync();

    expect(manifest, contains('<key>NSPrivacyTracking</key><false/>'));
    expect(manifest, contains('<key>NSPrivacyTrackingDomains</key><array/>'));

    const expectedTypes = <String>{
      'NSPrivacyCollectedDataTypeName',
      'NSPrivacyCollectedDataTypeEmailAddress',
      'NSPrivacyCollectedDataTypePhoneNumber',
      'NSPrivacyCollectedDataTypeHealth',
      'NSPrivacyCollectedDataTypeFitness',
      'NSPrivacyCollectedDataTypeUserID',
      'NSPrivacyCollectedDataTypeDeviceID',
      'NSPrivacyCollectedDataTypeOtherUserContent',
      'NSPrivacyCollectedDataTypeCustomerSupport',
      'NSPrivacyCollectedDataTypeEmailsOrTextMessages',
      'NSPrivacyCollectedDataTypePhotosorVideos',
      'NSPrivacyCollectedDataTypePurchaseHistory',
      'NSPrivacyCollectedDataTypeProductInteraction',
      'NSPrivacyCollectedDataTypeSearchHistory',
      'NSPrivacyCollectedDataTypePerformanceData',
      'NSPrivacyCollectedDataTypeOtherDiagnosticData',
      'NSPrivacyCollectedDataTypeOtherDataTypes',
    };
    final declaredTypes = RegExp(
      r'<key>NSPrivacyCollectedDataType</key>\s*<string>([^<]+)</string>',
    ).allMatches(manifest).map((match) => match.group(1)!).toSet();
    expect(declaredTypes, expectedTypes);

    for (final dataType in expectedTypes) {
      final declaration = _declarationFor(manifest, dataType);
      expect(declaration, isNotEmpty, reason: 'Missing $dataType');
      expect(
        declaration,
        contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'),
      );
      expect(
        declaration,
        matches(
          RegExp(r'<key>NSPrivacyCollectedDataTypeTracking</key>\s*<false/>'),
        ),
      );
      expect(
        declaration,
        matches(
          RegExp(
            '<key>NSPrivacyCollectedDataTypeLinked</key>\\s*'
            '<true/>',
          ),
        ),
        reason: '$dataType must remain conservatively account-linked',
      );
    }

    for (final excluded in <String>[
      'NSPrivacyCollectedDataTypeAudioData',
      'NSPrivacyCollectedDataTypeAdvertisingData',
      'NSPrivacyCollectedDataTypeCrashData',
      'NSPrivacyCollectedDataTypeContacts',
      'NSPrivacyCollectedDataTypePreciseLocation',
    ]) {
      expect(manifest, isNot(contains(excluded)));
    }
  });

  test('source evidence supports search, support, performance and diagnostics', () {
    final foodClient = File(
      'lib/features/nutrition/services/trusted_food_network_search_resolver.dart',
    ).readAsStringSync();
    final foodGateway = File(
      'supabase/functions/food-search/index.ts',
    ).readAsStringSync();
    final supportSchema = File(
      'supabase/migrations/202608110002_bil_diary_sharing_and_support_contracts.sql',
    ).readAsStringSync();
    final usageSchema = File(
      'supabase/migrations/202608110004_bil_ai_coach_weekly_usage_and_boost.sql',
    ).readAsStringSync();
    final observability = File(
      'lib/app/services/app_observability.dart',
    ).readAsStringSync();

    expect(foodClient, contains(".invoke(\n            'food-search'"));
    expect(foodClient, contains("'query': normalizedQuery"));
    expect(foodGateway, contains('readBoundedJsonObject(request)'));
    expect(foodGateway, contains('const body = boundedBody.value'));
    expect(
      foodGateway,
      contains('const query = text(body.query).replace(/\\s+/g, " ")'),
    );
    expect(foodGateway, contains('query.length < 2 || query.length > 120'));
    expect(foodGateway, contains('api.nal.usda.gov/fdc/v1/foods/search'));
    expect(foodGateway, isNot(contains('search_history')));

    expect(supportSchema, contains('public.bil_support_requests'));
    expect(supportSchema, contains('owner_id uuid not null'));
    expect(supportSchema, contains('p_client_context jsonb'));

    expect(usageSchema, contains('public.bil_ai_usage_events'));
    expect(usageSchema, contains('owner_id uuid not null'));
    expect(usageSchema, contains('latency_ms integer'));
    expect(observability, contains('DisabledProductAnalytics'));
    expect(observability, contains('LocalOnlyCrashReporter'));
    expect(observability, contains('bool get uploadsData => false'));
  });

  test('cloud, community, HealthKit and AI disclosures match active code', () {
    final profilePhoto = File(
      'lib/features/profile/services/profile_photo_service.dart',
    ).readAsStringSync();
    final communitySchema = File(
      'supabase/migrations/202608020002_bil_community_foundation.sql',
    ).readAsStringSync();
    final cloudPolicy = File(
      'lib/features/cloud_platform/providers/cloud_sync_providers.dart',
    ).readAsStringSync();
    final cloudProfile = File(
      'lib/features/cloud_platform/services/app_database_cloud_outbox_producer.dart',
    ).readAsStringSync();
    final coachContext = _librarySource(
      'lib/features/intelligence_center/services/coach_context_provider.dart',
    );
    final voicePolicy = File(
      'lib/features/intelligence_center/services/coach_voice_turn_policy.dart',
    ).readAsStringSync();
    final voiceUi = File(
      'lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart',
    ).readAsStringSync();
    final speechBridge = File(
      'ios/Runner/BILSpeechBridge.swift',
    ).readAsStringSync();

    expect(profilePhoto, contains(".from('profile-avatars')"));
    expect(profilePhoto, contains("'avatar_url': publicUrl"));
    for (final table in <String>[
      'bil_public_profiles',
      'bil_community_posts',
      'bil_messages',
      'bil_community_food_submissions',
      'bil_community_reports',
    ]) {
      expect(communitySchema, contains(table));
    }

    final enabledKinds = RegExp(
      r'enabledKinds: const <CloudEntityKind>\{([\s\S]*?)\}',
    ).firstMatch(cloudPolicy)?.group(1);
    expect(enabledKinds, isNotNull);
    expect(enabledKinds, contains('CloudEntityKind.profile'));
    expect(enabledKinds, contains('CloudEntityKind.weight'));
    expect(enabledKinds, contains('CloudEntityKind.hydration'));
    expect(enabledKinds, isNot(contains('CloudEntityKind.nutrition')));
    expect(cloudProfile, contains("'gender': row.gender"));
    expect(cloudProfile, contains("'age': row.age"));
    expect(
      cloudProfile,
      contains("'medicalConditions': row.medicalConditions"),
    );

    expect(coachContext, contains("'dietaryPreferences'"));
    expect(coachContext, contains('connectedHealth?.deviceVerified == true'));
    expect(
      coachContext,
      matches(
        RegExp(
          r"'sleep'\s*:\s*connectedSleep\s*!=\s*null[\s\S]*?"
          r"'source'\s*:\s*'connected_health'",
        ),
      ),
    );
    expect(voicePolicy, contains('maySendAudio: false'));
    expect(voiceUi, contains('textOverride: transcript'));
    expect(speechBridge, contains('SFSpeechRecognizer'));
    expect(speechBridge, contains('SFSpeechAudioBufferRecognitionRequest'));
  });

  test('public and in-app policies contain the reconciled privacy wording', () {
    final publicPolicy = File('public_site/app.js').readAsStringSync();
    final inAppPolicy = File(
      'lib/features/settings/legal_document_page.dart',
    ).readAsStringSync();
    final legacyCopy = File(
      'lib/app/localization/runtime_copy_extended.dart',
    ).readAsStringSync();
    final inventory = File(
      'docs/APP_STORE_PRIVACY_DATA_INVENTORY.md',
    ).readAsStringSync();

    for (final required in <String>[
      'Other sign-in options do not require a phone number.',
      'public Community avatar',
      'Private messages are stored with access controls but are not end-to-end encrypted.',
      'treats this authenticated processing as linked to the account',
      'the current selective sync scope is profile/body settings, weight, and hydration',
      'dietary preferences and recent nutrition, weight, activity, sleep, or verified connected-health summaries',
      'Google Gemini, a third-party AI service operated by Google',
      'Meal-photo analysis:',
      'Supabase service and authentication logs can include user ID, IP address, user agent',
      'stores only your language choice in browser local storage',
      'does not currently set BIL marketing cookies or load a BIL web-analytics beacon',
      'Cloudflare delivers and protects the public site',
    ]) {
      expect(publicPolicy, contains(required), reason: 'Missing: $required');
    }
    expect(publicPolicy, contains('رقم الهاتف عندما يطلبه مسار التسجيل'));
    expect(publicPolicy, contains('ليست مشفرة من طرف إلى طرف'));
    expect(publicPolicy, contains('لا يحمّل أداة تحليلات ويب من BIL'));

    expect(inAppPolicy, contains("bilLegalPolicyRevision = '2026-09-05'"));
    expect(
      inAppPolicy,
      contains('Google Gemini, a third-party AI service operated by Google'),
    );
    expect(inAppPolicy, contains('Raw microphone audio is not sent'));
    expect(inAppPolicy, isNot(contains('Meal images and voice are not sent')));
    expect(
      legacyCopy,
      isNot(contains('each microphone recording is sent once')),
    );
    expect(legacyCopy, isNot(contains('Without Global Voice')));

    for (final documented in <String>[
      'Search History | Yes | App Functionality',
      'Customer Support | Yes | App Functionality',
      'Performance Data | Yes | App Functionality',
      'Other Diagnostic Data | Yes | App Functionality',
      'Other Data Types | Yes | App Functionality; Product Personalization',
      'profile/body settings,',
      'weight records and hydration records',
      'Apple/platform speech recognition',
    ]) {
      expect(inventory, contains(documented));
    }
  });

  test('third-party AI consent is explicit and enforced before transmission', () {
    final coachUi = File(
      'lib/features/intelligence_center/presentation/intelligence_query_flow.dart',
    ).readAsStringSync();
    final mealConsent = File(
      'lib/features/nutrition/presentation/meal_vision_consent_gate.dart',
    ).readAsStringSync();
    final mealServer = File(
      'supabase/functions/analyze-meal/index.ts',
    ).readAsStringSync();
    final coachServer = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/202609240001_apple_ai_consent_policy_enforcement.sql',
    ).readAsStringSync();
    final mealConsentMigration = File(
      'supabase/migrations/20260924200207_allow_meal_vision_ai_consent.sql',
    ).readAsStringSync();

    for (final source in <String>[coachUi, mealConsent]) {
      expect(source, contains('third-party AI service operated by Google'));
      expect(source, contains('Google Gemini'));
    }
    expect(coachUi, contains("'p_policy_version': '3'"));
    expect(
      mealConsent,
      contains("mealVisionConsentPurpose = 'meal_vision_ai'"),
    );
    expect(mealConsent, contains('Nothing is logged until you confirm'));
    expect(mealServer, contains('meal_vision_ai_consent_required'));
    expect(
      mealServer.indexOf('meal_vision_ai_consent_required'),
      lessThan(mealServer.indexOf('bil_reserve_ai_vision')),
    );
    expect(coachServer, contains('bil_has_remote_ai_consent'));
    expect(migration, contains("r.policy_version = '3'"));
    expect(
      mealConsentMigration,
      contains("'remote_ai','cloud_sync','meal_vision_ai'"),
    );
    expect(mealConsentMigration, contains('to authenticated;'));
  });

  test('public website and iOS release stay tracking-free', () {
    final siteApp = File('public_site/app.js').readAsStringSync();
    final siteIndex = File('public_site/index.html').readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final releaseConfig = File(
      'ios/Flutter/Release.xcconfig',
    ).readAsStringSync();

    final storageKeys = RegExp(
      r"localStorage\.(?:getItem|setItem)\('([^']+)'",
    ).allMatches(siteApp).map((match) => match.group(1)!).toSet();
    expect(storageKeys, {'bil-site-language'});
    expect(siteApp, isNot(contains('document.cookie')));
    expect(siteIndex, isNot(contains('cloudflareinsights')));
    expect(siteIndex, isNot(contains('beacon.min.js')));

    expect(infoPlist, isNot(contains('NSUserTrackingUsageDescription')));
    expect(releaseConfig, contains('ca-app-pub-0000000000000000'));
  });

  test('iOS purpose strings match weight-only writes and current photo uses', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      infoPlist,
      contains(
        'BIL writes weight records only after you separately approve Health write access.',
      ),
    );
    expect(infoPlist, contains('community post, or food submission'));
    expect(infoPlist, isNot(contains('writes selected health records')));

    final localizedFiles = Directory('ios/Runner')
        .listSync()
        .whereType<Directory>()
        .where((directory) => directory.path.endsWith('.lproj'))
        .map((directory) => File('${directory.path}/InfoPlist.strings'))
        .where((file) => file.existsSync())
        .toList(growable: false);
    expect(localizedFiles, hasLength(25));
    for (final file in localizedFiles) {
      final strings = file.readAsStringSync();
      expect(
        RegExp(
          r'^"NSHealthUpdateUsageDescription"\s*=',
          multiLine: true,
        ).allMatches(strings),
        hasLength(1),
        reason: file.path,
      );
      expect(
        RegExp(
          r'^"NSPhotoLibraryUsageDescription"\s*=',
          multiLine: true,
        ).allMatches(strings),
        hasLength(1),
        reason: file.path,
      );
    }
  });
}
