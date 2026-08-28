import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('friend requests and acceptance are Premium-authorized by Supabase', () {
    final migration = File(
      'supabase/migrations/202608220003_premium_community_friendships.sql',
    ).readAsStringSync();

    expect(migration, contains('bil_has_active_premium'));
    expect(migration, contains("'premium'"));
    expect(migration, contains("'premium_ai_coach'"));
    expect(migration, contains("tg_op = 'INSERT'"));
    expect(migration, contains("old.status = 'pending'"));
    expect(migration, contains("new.status = 'accepted'"));
    expect(migration, contains("raise exception 'premium_required'"));
    expect(migration, contains('before insert or update of status'));
  });

  test(
    'client gates creating and accepting relationships on verified access',
    () {
      final people = File(
        'lib/features/community/presentation/community_people_page.dart',
      ).readAsStringSync();
      final connections = File(
        'lib/features/community/presentation/community_connections_page.dart',
      ).readAsStringSync();

      for (final source in [people, connections]) {
        expect(source, contains('verifiedSubscriptionStateProvider'));
        expect(source, contains('EntitlementAuthority.verifiedServer'));
        expect(source, contains('CommerceEntitlement.communityFriends'));
        expect(source, contains("'/plans?focus=subscription'"));
      }
    },
  );

  test('every community route is previewed behind the Premium glass gate', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final gate = File(
      'lib/features/commerce/presentation/premium_route_glass_gate.dart',
    ).readAsStringSync();

    expect(gate, contains('PremiumGateFeature.community'));
    expect(gate, contains("t('Friends and requests')"));
    expect(gate, contains("t('Messages')"));
    expect(
      RegExp(
        r"path: '/community(?:/[^']*)?'[\s\S]{0,260}PremiumGateFeature\.community",
      ).allMatches(router).length,
      10,
    );
  });
}
