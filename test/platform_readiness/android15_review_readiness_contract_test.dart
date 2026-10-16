import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'Android 33 release identity and modern Android package gates are exact',
    () {
      final gradle = _read('android/app/build.gradle.kts');
      final workflow = _read(
        '.github/workflows/bil_android_release_candidate.yml',
      );
      final manifest = _read(
        'docs/release/BIL_ANDROID_V33_FROZEN_SOURCE_MANIFEST_2026-10-14.md',
      );

      expect(gradle, contains('compileSdk = 36'));
      expect(gradle, contains('minSdk = 26'));
      expect(gradle, contains('targetSdk = 36'));
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('isShrinkResources = true'));
      expect(gradle, contains('abiFilters += listOf("arm64-v8a", "x86_64")'));

      expect(workflow, contains('(( BUILD_NUMBER == 33 ))'));
      expect(workflow, isNot(contains('(( BUILD_NUMBER == 29 ))')));
      expect(workflow, contains('BIL_ANDROID_V33_AUDITED_SOURCE_SHA'));
      expect(workflow, contains('BIL_IOS_V36_AUDITED_SOURCE_SHA'));
      expect(workflow, contains('BIL_ANDROID_V33_STAGING_MANIFEST_SHA256'));
      expect(
        workflow,
        contains('BIL_ANDROID_V33_FROZEN_SOURCE_MANIFEST_2026-10-14.md'),
      );
      expect(workflow, contains('BIL_MOBILE_INTEGRITY_REQUIRED=true'));
      expect(workflow, contains('BIL_PLAY_INTEGRITY_PROJECT_NUMBER'));
      expect(workflow, contains('BIL_PAYMENTS_ENABLED=true'));
      expect(workflow, contains('BIL_ADS_ENABLED=true'));
      expect(workflow, contains('BIL_FACEBOOK_REQUIRED: true'));
      expect(
        workflow,
        contains(
          'Verify final AAB SDK, optional hardware, 16 KB packaging, '
          'and ELF alignment',
        ),
      );
      expect(manifest, contains('RELEASE_BUILD_NUMBER: 33'));
      expect(manifest, contains('STAGING_MANIFEST_COMPLETE: YES'));
      expect(manifest, contains('CANDIDATE_FROZEN_OR_ACCEPTED: YES'));
    },
  );

  test(
    'Android privacy, Health Connect and Meta boundaries remain reviewable',
    () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');

      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:usesCleartextTraffic="false"'));

      for (final permission in <String>[
        'android.permission.health.READ_STEPS',
        'android.permission.health.READ_DISTANCE',
        'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
      ]) {
        expect(manifest, contains('android:name="$permission"'));
      }
      for (final rejectedPermission in <String>[
        'android.permission.health.READ_BODY_FAT',
        'android.permission.health.READ_RESTING_HEART_RATE',
        'android.permission.health.READ_SLEEP',
        'android.permission.health.READ_SLEEP_SESSION',
      ]) {
        expect(
          manifest,
          isNot(contains(rejectedPermission)),
          reason: 'Rejected Health Connect scope must stay absent.',
        );
      }

      expect(
        manifest,
        contains('androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE'),
      );
      expect(manifest, contains('android.intent.action.VIEW_PERMISSION_USAGE'));

      // Meta's native Android SDK has been removed. Browser-based Supabase
      // OAuth does not need native SDK metadata; keep both the manifest and
      // dependency graph free of a dormant SDK configuration.
      expect(manifest, isNot(contains('com.facebook.sdk.')));
      final androidDependencies = [
        _read('pubspec.yaml'),
        _read('pubspec.lock'),
        _read('android/app/build.gradle.kts'),
        _read('android/settings.gradle.kts'),
      ].join('\n');
      for (final nativeMetaDependency in <String>[
        'com.facebook.android',
        'flutter_facebook_auth',
        'facebook_app_events',
      ]) {
        expect(
          androidDependencies,
          isNot(contains(nativeMetaDependency)),
          reason: 'Native Meta SDK dependency must stay absent.',
        );
      }

      for (final permission in <String>[
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.WRITE_EXTERNAL_STORAGE',
        'com.google.android.gms.permission.AD_ID',
        'android.permission.ACCESS_ADSERVICES_AD_ID',
        'android.permission.ACCESS_ADSERVICES_TOPICS',
        'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
        'android.permission.ACCESS_ADSERVICES_CUSTOM_AUDIENCE',
      ]) {
        final escaped = RegExp.escape(permission);
        expect(
          RegExp(
            'android:name="$escaped"[\\s\\S]{0,180}?tools:node="remove"',
          ).hasMatch(manifest),
          isTrue,
          reason: '$permission must be removed at manifest merge.',
        );
      }
    },
  );

  test(
    'reviewer, subscription, health-safety and UGC surfaces stay present',
    () {
      final login = _read('lib/features/auth/premium_login_page.dart');
      final store = _read(
        'lib/features/commerce/presentation/bil_store_plans_page.dart',
      );
      final copy = _read(
        'lib/features/commerce/presentation/bil_store_copy.dart',
      );
      final community = _read(
        'lib/features/community/presentation/community_safety_page.dart',
      );
      final sources = _read(
        'lib/features/settings/health_information_sources_page.dart',
      );

      expect(login, contains("Key('store-reviewer-access')"));
      expect(store, contains('_restorePurchases'));
      expect(store, contains('openManageSubscriptions'));
      expect(copy, contains('Renews automatically until canceled.'));
      expect(copy, contains('7 days free'));
      expect(community, contains('Report, block, and delete'));
      expect(community, contains('Accept policy'));
      expect(sources, contains('BIL does not diagnose medical conditions'));
      expect(sources, contains('qualified health professional'));
    },
  );

  test(
    'AI Boost remains aligned to the canonical Play/StoreKit product id',
    () {
      final catalog = _read(
        'lib/features/commerce/domain/store_catalog_configuration.dart',
      );
      final migration = _read(
        'supabase/migrations/'
        '20260914101500_align_ai_boost_product_id_with_storekit.sql',
      );

      expect(catalog, contains("'bil_ai_boost'"));
      expect(migration, contains("check (product_id = 'bil_ai_boost')"));
    },
  );
}
