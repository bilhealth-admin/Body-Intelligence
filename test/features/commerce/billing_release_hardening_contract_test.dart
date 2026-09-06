import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed workflows preserve commerce and owner-defer ads', () {
    final workflows =
        <
          String,
          ({String prepareMode, String verifyMode, String nativeMarker})
        >{
          '.github/workflows/bil_android_release_candidate.yml': (
            prepareMode: '--prepare-android-source-manifest',
            verifyMode: '--verify-android-merged-manifest',
            nativeMarker:
                'ADMOB_ANDROID_DEFERRED_NATIVE_CONFIGURATION_GATE=PASS',
          ),
          '.github/workflows/bil_ios_signed_release.yml': (
            prepareMode: '--prepare-ios-source-plist',
            verifyMode: '--verify-ios-final-plist',
            nativeMarker: 'ADMOB_IOS_DEFERRED_NATIVE_CONFIGURATION_GATE=PASS',
          ),
        };

    for (final entry in workflows.entries) {
      final path = entry.key;
      final source = File(path).readAsStringSync();
      expect(source, contains('--dart-define=BIL_PAYMENTS_ENABLED=true'));
      expect(source, contains('--dart-define=BIL_ENVIRONMENT=production'));
      expect(source, contains('BIL_ADS_ENABLED: false'));
      expect(source, contains('BIL_AD_PROVIDER_READY: false'));
      expect(
        source,
        contains('--dart-define=BIL_TERMS_URL=https://www.bilhealth.com/terms'),
      );
      expect(
        source,
        contains(
          '--dart-define=BIL_PRIVACY_URL=https://www.bilhealth.com/privacy',
        ),
      );
      expect(
        source,
        contains(
          '--dart-define=BIL_MEAL_VISION_ENDPOINT=https://tgmanzhqulksykhslrzb.supabase.co/functions/v1/analyze-meal',
        ),
      );
      expect(
        source,
        contains(
          '--dart-define=BIL_WELLNESS_MANIFEST_URL=https://workouts.bilhealth.com/v2/manifest/wellness-workouts-v2-af6082ff28856f9154216067f16fe6a7147548c9a29f8e205b43bb81bc34efe8.json',
        ),
      );
      for (final define in <String>[
        'BIL_RECIPE_IMAGE_DELIVERY_ENABLED=true',
        'BIL_FACEBOOK_LOGIN_ENABLED=true',
        'BIL_FACEBOOK_LOGIN_READY=true',
        'BIL_ADS_ENABLED=false',
        'BIL_AD_PROVIDER_READY=false',
        'BIL_ENABLE_CATALOG_TEST_ACCESS=false',
      ]) {
        expect(
          source,
          contains('--dart-define=$define'),
          reason: '$path: $define',
        );
      }
      expect(
        source,
        contains('tool/release/configure_deferred_admob.py'),
        reason: '$path must prepare and verify the deferred native state',
      );
      expect(
        source,
        contains('python3 tool/release/test_configure_deferred_admob.py'),
        reason: '$path must run the deferred native helper regressions',
      );
      for (final productionToken in <String>[
        'BIL_ADMOB_PRODUCTION_READY',
        'BIL_ADMOB_PUBLISHER_ID',
        'BIL_ADMOB_ANDROID_APP_ID',
        'BIL_ADMOB_ANDROID_BANNER_ID',
        'BIL_ADMOB_IOS_APP_ID',
        'BIL_ADMOB_IOS_BANNER_ID',
        'validate_admob_production_configuration.py',
      ]) {
        expect(
          source,
          isNot(contains(productionToken)),
          reason: '$path must not consume deferred production AdMob input',
        );
      }

      final portableTests = source.indexOf('run_portable_release_tests.py');
      final nativeSourceTests = source.indexOf(
        'integration_test/system_crypto_bridge_integration_test.dart',
      );
      final sanitizer = source.indexOf(
        'dart run tool/release/sanitize_flutter_release_plugins.dart',
      );
      final helperTests = source.indexOf(
        'python3 tool/release/test_configure_deferred_admob.py',
      );
      final prepare = source.indexOf(entry.value.prepareMode);
      final build = source.indexOf('flutter build');
      final verify = source.indexOf(entry.value.verifyMode);
      final nativeMarker = source.indexOf(entry.value.nativeMarker);
      expect(portableTests, greaterThanOrEqualTo(0), reason: path);
      expect(nativeSourceTests, greaterThanOrEqualTo(0), reason: path);
      expect(prepare, greaterThan(nativeSourceTests), reason: path);
      expect(prepare, greaterThan(portableTests), reason: path);
      expect(sanitizer, greaterThan(nativeSourceTests), reason: path);
      expect(helperTests, greaterThan(sanitizer), reason: path);
      expect(prepare, greaterThan(helperTests), reason: path);
      expect(prepare, lessThan(build), reason: path);
      expect(verify, greaterThan(build), reason: path);
      expect(nativeMarker, greaterThan(verify), reason: path);
      expect(
        source,
        contains('ADS_COMPILED_GATE=DISABLED_OWNER_DEFERRED'),
        reason: path,
      );
    }
  });

  test('AI and Boost access providers are scoped to the current owner', () {
    final source = File(
      'lib/features/commerce/providers/commerce_providers.dart',
    ).readAsStringSync();
    expect(
      'ref.watch(verifiedEntitlementOwnerProvider)'.allMatches(source).length,
      greaterThanOrEqualTo(3),
    );
  });

  test('pending migration normalizes AI access from canonical entitlement', () {
    final source = File(
      'supabase/migrations/20260830120109_canonical_store_lifecycle_mirror_forward_20260830110000.sql',
    ).readAsStringSync();
    expect(source, contains('bil_sync_ai_coach_store_subscription'));
    expect(source, contains("new.lifecycle = 'cancelled' then 'active'"));
    expect(source, contains('when v_boundary is null then'));
    expect(source, contains("provider in ('google', 'apple')"));
    expect(source, contains('Closed-test grants are a separate'));
  });
}
