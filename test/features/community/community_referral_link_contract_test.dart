import 'dart:io';

import 'package:body_intelligence_log/app/analytics/bil_launch_deep_link.dart';
import 'package:body_intelligence_log/features/community/domain/community_referral.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef0123456789abcdef';

  test(
    'installed-app referral links resolve through the audited allow-list',
    () {
      const route = '/community/invite/$token';
      expect(
        CommunityDeepLink.routeFor(Uri.parse('bil://invite/$token')),
        route,
      );
      expect(
        CommunityDeepLink.routeFor(Uri.parse('bil://community/invite/$token')),
        route,
      );
      expect(
        BilLaunchDeepLink.parse(
          Uri.parse('https://www.bilhealth.com/invite/$token'),
        )?.route,
        route,
      );
      expect(
        BilLaunchDeepLink.parse(
          Uri.parse('https://bilhealth.com/invite/$token'),
        )?.route,
        route,
      );
      expect(
        BilLaunchDeepLink.parse(
          Uri.parse('https://www.bilhealth.com/invite/not-a-token'),
        ),
        isNull,
      );
    },
  );

  test(
    'referral acceptance requires the server-created friendship receipt',
    () {
      final acceptance = CommunityInviteAcceptance.fromJson({
        'status': 'attributed',
        'duplicate': false,
        'attribution_id': '11111111-1111-4111-8111-111111111111',
        'inviter_id': '22222222-2222-4222-8222-222222222222',
        'display_name': 'BIL inviter',
        'avatar_url': null,
        'handle': 'bil_inviter',
        'friendship_id': '33333333-3333-4333-8333-333333333333',
        'relationship': 'accepted',
        'new_account_eligible': true,
      });
      expect(acceptance.relationshipAccepted, isTrue);
      expect(acceptance.newAccountEligible, isTrue);

      expect(
        () => CommunityInviteAcceptance.fromJson({
          'status': 'attributed',
          'duplicate': false,
          'attribution_id': '11111111-1111-4111-8111-111111111111',
          'inviter_id': '22222222-2222-4222-8222-222222222222',
          'friendship_id': null,
          'relationship': 'accepted',
        }),
        throwsFormatException,
      );
    },
  );

  test('native association sources claim only the public invite prefix', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final verifiedLinks = File(
      'lib/app/launch/bil_verified_links_configuration.dart',
    ).readAsStringSync();
    final generator = File(
      'tool/release/generate_app_link_associations.py',
    ).readAsStringSync();
    final worker = File(
      'tool/release/bilhealth_site_worker.mjs',
    ).readAsStringSync();

    expect(manifest, contains('android:pathPrefix="/invite/"'));
    expect(
      verifiedLinks,
      contains("publicCommunityPaths = <String>['/invite/*']"),
    );
    expect(generator, contains('PUBLIC_COMMUNITY_PATHS = ("/invite/*",)'));
    expect(worker, contains("REQUIRED_PUBLIC_PATHS = new Set(['/invite/*'])"));
  });

  test('invite landing uses atomic friendship instead of a second request', () {
    final landing = File(
      'lib/features/community/presentation/community_invite_landing_page.dart',
    ).readAsStringSync();
    final router = [
      File('lib/app/router/app_router.dart').readAsStringSync(),
      File('lib/app/router/app_community_routes.dart').readAsStringSync(),
    ].join('\n');

    expect(landing, contains('relationshipAccepted'));
    expect(landing, contains('community-open-inviter-profile'));
    expect(landing, isNot(contains('requestFriend(inviterId)')));
    expect(router, contains("path: '/community/invite/:token'"));

    final routeStart = router.indexOf("path: '/community/invite/:token'");
    final nextRoute = router.indexOf('GoRoute(', routeStart + 8);
    final block = router.substring(
      routeStart,
      nextRoute > routeStart ? nextRoute : router.length,
    );
    expect(block, isNot(contains('PremiumRouteGlassGate')));
  });
}
