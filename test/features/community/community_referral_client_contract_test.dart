import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_referral.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('referral domain validates opaque token and attribution states', () {
    const token = '0123456789abcdef0123456789abcdef0123456789abcdef';
    final created = CommunityInviteCreateResult.fromJson({
      'status': 'active',
      'invite_id': '11111111-1111-4111-8111-111111111111',
      'token': token,
      'url': 'https://www.bilhealth.com/invite/$token',
      'expires_at': '2026-11-02T00:00:00Z',
    });
    expect(created.active, isTrue);
    expect(created.url?.host, 'www.bilhealth.com');

    final accepted = CommunityInviteAcceptance.fromJson({
      'status': 'attributed',
      'duplicate': false,
      'attribution_id': '22222222-2222-4222-8222-222222222222',
      'inviter_id': '33333333-3333-4333-8333-333333333333',
      'display_name': 'BIL Member',
      'avatar_url': null,
      'handle': 'bil_member',
      'friendship_id': '44444444-4444-4444-8444-444444444444',
      'relationship': 'accepted',
      'new_account_eligible': true,
    });
    expect(accepted.attributed, isTrue);
    expect(accepted.relationshipAccepted, isTrue);

    expect(
      () => CommunityInviteCreateResult.fromJson({
        'status': 'active',
        'invite_id': '1',
        'token': 'short',
        'url': 'https://evil.example/invite/short',
        'expires_at': '2026-11-02T00:00:00Z',
      }),
      throwsFormatException,
    );
  });

  test('invite landing is pre-entitlement and cannot grant rewards', () {
    final router = [
      File('lib/app/router/app_router.dart').readAsStringSync(),
      File('lib/app/router/app_community_routes.dart').readAsStringSync(),
    ].join('\n');
    final page = File(
      'lib/features/community/presentation/community_invite_landing_page.dart',
    ).readAsStringSync();
    final repository = [
      'lib/features/community/data/community_repository.dart',
      'lib/features/community/data/community_repository_discovery_mixin.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final people = File(
      'lib/features/community/presentation/community_people_page.dart',
    ).readAsStringSync();

    final routeStart = router.indexOf("path: '/community/invite/:token'");
    expect(routeStart, greaterThanOrEqualTo(0));
    final nextRoute = router.indexOf('\n      GoRoute(', routeStart + 1);
    final routeBlock = router.substring(
      routeStart,
      nextRoute < 0 ? router.length : nextRoute,
    );
    expect(routeBlock, contains('CommunityInviteLandingPage'));
    expect(routeBlock, isNot(contains('PremiumRouteGlassGate')));

    expect(page, contains('previewCommunityInvite'));
    expect(page, contains('acceptCommunityInvite'));
    expect(page, contains('relationshipAccepted'));
    expect(page, isNot(contains('requestFriend(inviterId)')));
    expect(page, isNot(contains('bil_set_community_referral_integrity_v1')));
    expect(page, isNot(contains('bil_post_gold_ledger_v1')));
    expect(page, isNot(contains('claimCommunityQuest')));

    expect(repository, contains('bil_create_community_invite_v1'));
    expect(repository, contains('bil_preview_community_invite_v1'));
    expect(repository, contains('bil_accept_community_invite_v1'));
    expect(
      repository,
      isNot(contains('bil_set_community_referral_integrity_v1')),
    );

    expect(people, contains('createCommunityInvite'));
    expect(people, contains('trackedInviteUrl'));
    expect(people, contains('bilCommunityInviteMessage'));
  });

  test('tracked invite copy retains a generic fail-closed fallback', () {
    final copy = File(
      'lib/features/community/presentation/community_invite_copy.dart',
    ).readAsStringSync();

    expect(
      copy,
      contains(
        "const bilCommunityInviteDownloadUrl = 'https://www.bilhealth.com/download'",
      ),
    );
    expect(copy, contains('String? url'));
    expect(copy, contains('bilCommunityInviteDownloadUrl'));
  });
}
