import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium labels and AdGate consume verified entitlement only', () {
    final surfaces = <String>[
      'lib/features/settings/settings_page.dart',
      'lib/features/profile/profile_summary_page.dart',
      'lib/features/ads/providers/ad_providers.dart',
    ];

    for (final path in surfaces) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('verifiedSubscriptionStateProvider'),
        reason: path,
      );
      expect(
        source,
        isNot(contains('ref.watch(subscriptionStateProvider)')),
        reason: path,
      );
    }

    final settings = File(surfaces[0]).readAsStringSync();
    final profile = File(surfaces[1]).readAsStringSync();
    expect(settings, contains('Retry subscription check'));
    expect(settings, contains("copy('Start 7-day free trial')"));
    expect(settings, isNot(contains("copy('Try Premium for Free')")));
    expect(profile, contains('Retry subscription check'));
  });

  test('server entitlement fails closed before Supabase is initialized', () {
    final source = File(
      'lib/features/commerce/repositories/server_entitlement_repository.dart',
    ).readAsStringSync();
    expect(source, contains('AppEnvironment.supabaseRuntimeReady'));
    expect(source, contains('return FreePlan.createState();'));
    expect(
      source.indexOf('AppEnvironment.supabaseRuntimeReady'),
      lessThan(source.indexOf('Supabase.instance.client')),
    );
  });

  test('verified entitlement follows the Supabase owner lifecycle', () {
    final source = File(
      'lib/features/commerce/providers/commerce_providers.dart',
    ).readAsStringSync();

    expect(source, contains('verifiedEntitlementOwnerProvider'));
    expect(source, contains('auth.currentUser?.id'));
    expect(source, contains('auth.onAuthStateChange'));
    expect(source, contains('state.session?.user.id'));
    expect(source, contains('ref.watch(verifiedEntitlementOwnerProvider)'));
  });

  test('closed-test grant is a server-owned Premium AI Coach overlay', () {
    final source = File(
      'lib/features/commerce/repositories/server_entitlement_repository.dart',
    ).readAsStringSync();
    expect(source, contains("from('bil_ai_closed_test_grants')"));
    expect(source, contains('closedTestActive'));
    expect(source, contains('CommercePlan.premiumAiCoach'));
    expect(source, isNot(contains('userMetadata')));
    expect(source, isNot(contains('raw_user_meta_data')));

    final migration = File(
      'supabase/migrations/202608220002_closed_test_ai_overlay.sql',
    ).readAsStringSync();
    expect(migration, contains('bil_sync_ai_closed_test_grant'));
    expect(migration, contains("'closed_test'"));
    expect(migration, contains("'bil_closed_test'"));
  });
}
