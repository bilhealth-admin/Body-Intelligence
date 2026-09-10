import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Free migration removes only commerce gates after safety preflight', () {
    final migration = File(
      'supabase/migrations/20260910090403_community_and_friendships_free.sql',
    ).readAsStringSync();
    expect(migration, contains('relrowsecurity'));
    expect(migration, contains('bil_000_friendships_write_contract'));
    expect(migration, contains('bil_00_friendships_member_access'));
    expect(migration, contains('free_friendships_rpc_acl_drift'));
    expect(
      migration,
      contains('drop trigger if exists bil_friendships_require_premium'),
    );
    expect(
      migration,
      contains(
        'drop function if exists public.bil_require_premium_friendship()',
      ),
    );
    expect(
      migration,
      isNot(
        matches(
          RegExp(
            r'^\s*(?:grant|update|delete from|insert into|alter table|drop policy)\b',
            caseSensitive: false,
            multiLine: true,
          ),
        ),
      ),
    );
  });

  test('friend actions never depend on billing or administrative status', () {
    for (final path in [
      'lib/features/community/presentation/community_people_page.dart',
      'lib/features/community/presentation/community_connections_page.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('verifiedSubscriptionStateProvider')));
      expect(source, isNot(contains('aiCoachAdminAccessProvider')));
      expect(source, isNot(contains('/plans')));
      expect(source, contains('CommunityRepository'));
    }
  });

  test('all existing community entry points share the Free bypass', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final gate = File(
      'lib/features/commerce/presentation/premium_route_glass_gate.dart',
    ).readAsStringSync();
    expect(
      gate,
      contains('if (feature == PremiumGateFeature.community) return child;'),
    );
    expect(
      RegExp(
        r"path: '/community(?:/[^']*)?'[\s\S]{0,260}PremiumGateFeature\.community",
      ).allMatches(router).length,
      13,
    );
    expect(
      router,
      matches(
        RegExp(
          r"path: '/community/moderation'[\s\S]{0,260}CommunityPostModerationPage",
        ),
      ),
    );
  });

  test('plans describe friends and messages under Free, not paid benefits', () {
    final source = File(
      'lib/features/commerce/presentation/bil_dynamic_store_offers.dart',
    ).readAsStringSync();
    final paidStart = source.indexOf('static const _premiumPaidBenefitKeys');
    final paidEnd = source.indexOf(
      'static const _premiumCoreBenefitKeys',
      paidStart,
    );
    final paid = source.substring(paidStart, paidEnd);
    expect(paid, isNot(contains('premium_benefit_community')));
    expect(paid, isNot(contains('premium_benefit_messages')));
    final freeStart = source.indexOf('_FreeTierCard(');
    final freeEnd = source.indexOf('currentLabel:', freeStart);
    final free = source.substring(freeStart, freeEnd);
    expect(free, contains("_copy('premium_benefit_community')"));
    expect(free, contains("_copy('premium_benefit_messages')"));
  });
}
