import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed release workflows enable commerce and legal links', () {
    for (final path in <String>[
      '.github/workflows/bil_android_release_candidate.yml',
      '.github/workflows/bil_ios_signed_release.yml',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('--dart-define=BIL_PAYMENTS_ENABLED=true'));
      expect(source, contains('--dart-define=BIL_ENVIRONMENT=production'));
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
        'BIL_FACEBOOK_LOGIN_ENABLED=false',
        'BIL_FACEBOOK_LOGIN_READY=false',
        'BIL_ADS_ENABLED=false',
        'BIL_AD_PROVIDER_READY=false',
        'BIL_ENABLE_CATALOG_TEST_ACCESS=false',
      ]) {
        expect(source, contains('--dart-define=$define'), reason: '$path: $define');
      }
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
