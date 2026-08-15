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
    expect(settings, contains("copy('Explore Premium')"));
    expect(settings, isNot(contains("copy('Try Premium for Free')")));
    expect(profile, contains('Retry subscription check'));
  });

  test('server entitlement fails closed before Supabase is initialized', () {
    final source = File(
      'lib/features/commerce/repositories/server_entitlement_repository.dart',
    ).readAsStringSync();
    expect(source, contains('Supabase.instance.isInitialized'));
    expect(source, contains('return FreePlan.createState();'));
    expect(
      source.indexOf('Supabase.instance.isInitialized'),
      lessThan(source.indexOf('Supabase.instance.client')),
    );
  });
}
