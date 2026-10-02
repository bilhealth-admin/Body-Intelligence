import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paywall exposes configured Terms and Privacy links', () {
    final source = File(
      'lib/features/commerce/presentation/commerce_paywall.dart',
    ).readAsStringSync();
    expect(source, contains('StoreCatalogConfiguration.legalLinksConfigured'));
    expect(source, contains("Key('paywall-terms-link')"));
    expect(source, contains("Key('paywall-privacy-link')"));
    expect(source, contains('StoreCatalogConfiguration.termsUrl'));
    expect(source, contains('StoreCatalogConfiguration.privacyUrl'));
  });

  test('signed workflows preserve commerce and production AdMob', () {
    const workflows = <String, String>{
      '.github/workflows/bil_android_release_candidate.yml':
          'ADMOB_ANDROID_PRODUCTION_CONFIGURATION_GATE=PASS',
      '.github/workflows/bil_ios_signed_release.yml':
          'ADMOB_IOS_PRODUCTION_CONFIGURATION_GATE=PASS',
    };

    for (final entry in workflows.entries) {
      final path = entry.key;
      final source = File(path).readAsStringSync();
      expect(source, contains('--dart-define=BIL_PAYMENTS_ENABLED=true'));
      expect(source, contains('--dart-define=BIL_ENVIRONMENT=production'));
      expect(source, contains('BIL_ADS_ENABLED: true'));
      expect(source, contains('BIL_AD_PROVIDER_READY: true'));
      expect(source, contains('BIL_ADMOB_PRODUCTION_READY: true'));
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
        'BIL_ADS_ENABLED=true',
        'BIL_AD_PROVIDER_READY=true',
        'BIL_ADMOB_PUBLISHER_ID=pub-9688223318643509',
        'BIL_ENABLE_CATALOG_TEST_ACCESS=false',
      ]) {
        expect(
          source,
          contains('--dart-define=$define'),
          reason: '$path: $define',
        );
      }
      for (final token in <String>[
        'BIL_ADMOB_ANDROID_APP_ID',
        'BIL_ADMOB_ANDROID_BANNER_ID',
        'BIL_ADMOB_IOS_APP_ID',
        'BIL_ADMOB_IOS_BANNER_ID',
        'validate_admob_production_configuration.py',
      ]) {
        expect(source, contains(token), reason: path);
      }
      expect(
        source,
        isNot(contains('configure_deferred_admob.py')),
        reason: '$path must not strip AdMob from the production candidate',
      );
      expect(
        source,
        contains('ADS_COMPILED_GATE=ENABLED_PRODUCTION'),
        reason: path,
      );
      expect(source, contains(entry.value), reason: path);
    }

    final ios = File(
      '.github/workflows/bil_ios_signed_release.yml',
    ).readAsStringSync();
    expect(
      ios,
      contains(
        'dart run tool/release/sanitize_flutter_release_plugins.dart --platform=ios',
      ),
    );
    expect(ios, isNot(contains('--defer-ios-google-mobile-ads')));
    expect(ios, contains("grep -Fq 'FLTGoogleMobileAdsPlugin'"));
  });

  test('AI and Boost access providers are scoped to the current owner', () {
    final source = File(
      'lib/features/commerce/providers/commerce_providers.dart',
    ).readAsStringSync();
    // Verify each boundary, not the number of mentions of the async owner
    // stream. Stable owner IDs deliberately avoid same-account startup reloads.
    for (final provider in [
      'verifiedSubscriptionStateProvider',
      'aiCoachCreditAccessProvider',
      'aiBoostVisionAccessProvider',
    ]) {
      expect(source, contains('final $provider ='));
      final body = source
          .split('final $provider =')
          .last
          .split('\nfinal ')
          .first;
      expect(
        RegExp(
          r'ref.watch\(verifiedEntitlementOwner(?:Id)?Provider\)',
        ).hasMatch(body),
        isTrue,
        reason: '$provider must invalidate on an authenticated owner change.',
      );
    }
    final stableOwner = source
        .split('final verifiedEntitlementOwnerIdProvider =')
        .last
        .split('\nfinal ')
        .first;
    expect(
      stableOwner,
      contains('ref.watch(verifiedEntitlementOwnerProvider)'),
    );
    expect(stableOwner, contains('if (owner.hasValue) return owner.value;'));
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

  test(
    'iOS subscription checkout refreshes and recovers StoreKit2 duplicates',
    () {
      final service = File(
        'lib/features/commerce/services/verified_store_purchase_service.dart',
      ).readAsStringSync();
      final processing = File(
        'lib/features/commerce/services/verified_store_purchase_processing.dart',
      ).readAsStringSync();

      expect(service, contains("defaultTargetPlatform == TargetPlatform.iOS"));
      expect(service, contains("storekit_duplicate_product_object"));
      expect(service, contains("_reconcileAppleUnfinishedBeforePurchase"));
      expect(service, contains("SK2Transaction.unfinishedTransactions()"));
      expect(service, contains("SK2PurchaseDetails("));
      expect(service, contains("_handleVerifiedPurchase("));
      expect(service, contains("source: 'app_store'"));
      expect(service, contains("_appleDuplicateRetryInFlight"));
      expect(service, contains("queryProductDetails({displayed.id})"));
      expect(processing, contains("_recoverVerifiedStoreKit2Completion"));
      expect(processing, contains("SK2Transaction.unfinishedTransactions()"));
      expect(processing, contains("SK2Transaction.finish("));
    },
  );
}
