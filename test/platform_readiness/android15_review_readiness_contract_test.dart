import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'Android 15 release identity and modern Android package gates are exact',
    () {
      final gradle = _read('android/app/build.gradle.kts');
      final workflow = _read(
        '.github/workflows/bil_android_release_candidate.yml',
      );

      expect(gradle, contains('compileSdk = 36'));
      expect(gradle, contains('minSdk = 26'));
      expect(gradle, contains('targetSdk = 36'));
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('isShrinkResources = true'));
      expect(gradle, contains('abiFilters += listOf("arm64-v8a", "x86_64")'));

      expect(workflow, contains('(( BUILD_NUMBER == 15 ))'));
      expect(workflow, isNot(contains('(( BUILD_NUMBER == 14 ))')));
      expect(workflow, contains('BIL_ANDROID_V15_AUDITED_SOURCE_SHA'));
      expect(workflow, contains('BIL_ANDROID_V15_STAGING_MANIFEST_SHA256'));
      expect(
        workflow,
        contains('BIL_ANDROID_V15_FROZEN_SOURCE_MANIFEST_2026-09-14.md'),
      );
      expect(workflow, contains('BIL_MOBILE_INTEGRITY_REQUIRED=true'));
      expect(workflow, contains('BIL_PLAY_INTEGRITY_PROJECT_NUMBER'));
      expect(workflow, contains('BIL_PAYMENTS_ENABLED=true'));
      expect(workflow, contains('BIL_ADS_ENABLED=false'));
      expect(workflow, contains('BIL_FACEBOOK_REQUIRED: true'));
      expect(
        workflow,
        contains(
          'Verify final AAB SDK, optional hardware, 16 KB packaging, '
          'and ELF alignment',
        ),
      );
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

      expect(
        manifest,
        contains('androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE'),
      );
      expect(manifest, contains('android.intent.action.VIEW_PERMISSION_USAGE'));

      for (final metaKey in <String>[
        'com.facebook.sdk.AutoLogAppEventsEnabled',
        'com.facebook.sdk.AdvertiserIDCollectionEnabled',
      ]) {
        expect(
          RegExp(
            'android:name="$metaKey"[\\s\\S]{0,180}?android:value="false"',
          ).hasMatch(manifest),
          isTrue,
          reason: '$metaKey must remain disabled in production.',
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
