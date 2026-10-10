import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every audited Community detail AppBar has an explicit safe Back', () {
    // Community itself is one of the five permanent bottom tabs; its root
    // AppBar intentionally has no Back. Every routed child listed here may
    // instead be opened by an alert, scan, accepted friendship, or deep link.
    const audited = <String, int>{
      'lib/features/community/presentation/community_connections_page.dart': 1,
      'lib/features/community/presentation/community_people_page.dart': 1,
      'lib/features/community/presentation/community_profile_page.dart': 1,
      'lib/features/community/presentation/community_post_moderation_page.dart': 1,
      'lib/features/community/presentation/community_notifications_rendering.dart': 1,
      'lib/features/community/presentation/community_messages_page.dart': 1,
      'lib/features/community/presentation/community_message_owner_scope.dart': 1,
      'lib/features/community/presentation/community_entry_gate.dart': 1,
      'lib/features/community/presentation/community_member_profile_drafts.dart': 1,
      'lib/features/community/presentation/community_post_owner_scope.dart': 1,
      'lib/features/community/presentation/community_post_composer_owner_scope.dart': 1,
      'lib/features/community/presentation/community_chat_rendering.dart': 1,
      'lib/features/community/presentation/new_community_message_page.dart': 3,
      'lib/features/community/presentation/community_safety_page.dart': 1,
      'lib/features/community/presentation/community_invite_landing_page.dart': 1,
      'lib/features/community/presentation/community_bil_code_page.dart': 3,
      'lib/features/community/presentation/community_food_review_page.dart': 1,
      'lib/features/community/presentation/community_post_gallery_page.dart': 1,
      'lib/features/community/presentation/community_saved_posts_page.dart': 1,
      'lib/features/community/presentation/community_my_posts_page.dart': 1,
      'lib/features/community/presentation/community_circle_detail_page.dart': 2,
      'lib/features/community/presentation/community_member_profile_page.dart': 1,
      'lib/features/community/presentation/community_circles_page.dart': 1,
      'lib/features/community/presentation/community_post_detail_rendering.dart': 1,
      'lib/features/community/presentation/community_post_widgets.dart': 1,
      'lib/features/community/presentation/community_topics_page.dart': 2,
      'lib/features/community/presentation/community_rewards_page.dart': 1,
      'lib/features/community/presentation/community_compose_entry_page.dart': 1,
      'lib/features/community/channels/presentation/community_channels_page.dart': 1,
      'lib/features/community/channels/presentation/community_channels_route.dart': 1,
      'lib/features/community/activity_rewards/community_post_receipt_page.dart': 1,
    };
    final appBars = RegExp(r'AppBar\(');
    final explicitReturn = RegExp(
      r'leading:\s*(?:const\s+)?CommunityReturnButton\(|'
      r'leading:\s*AbsorbPointer\(',
    );
    for (final entry in audited.entries) {
      final source = File(entry.key).readAsStringSync();
      final count = appBars.allMatches(source).length;
      final backed = explicitReturn.allMatches(source).length;
      expect(count, entry.value, reason: 'Review changed page count: ${entry.key}');
      expect(backed, count, reason: 'Missing Back on ${entry.key}');
    }
  });

  test('Community tab and its modal subpages use the right Back rule', () {
    final source = File(
      'lib/features/community/presentation/community_hub_page.dart',
    ).readAsStringSync();
    // The five-tab Community root must not grow a decorative Back arrow, but
    // a pushed Community route must expose its actual previous page.
    expect(source, contains('leading: Navigator.of(context).canPop()'));
    expect(source, contains('automaticallyImplyLeading: false'));
    expect(RegExp(r'AppBar\(').allMatches(source).length, 3);
    expect(
      RegExp(
        r'leading:\s*(?:const\s+)?CommunityReturnButton\(',
      ).allMatches(source).length,
      2,
    );
  });

  test('cold link registration preserves Back rather than replacing routes', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final notifications = File(
      'lib/features/notifications/services/inactivity_reminder_coordinator.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/app/router/bil_external_route_navigator.dart',
    ).readAsStringSync();
    expect(router, contains('BilExternalRouteNavigator(router).open(route)'));
    expect(main, contains('navigate: AppRouter.openExternalRoute'));
    expect(
      notifications,
      contains('navigate: AppRouter.openExternalRoute'),
    );
    expect(navigation, contains('router.push(location)'));
    expect(navigation, contains("'/community/messages'"));
  });

  test('important non-Community deep links have an explicit safe Back', () {
    for (final path in <String>[
      'lib/features/settings/legal_document_page.dart',
      'lib/features/settings/trust_support_page.dart',
      'lib/features/settings/help_center_page.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('BilSafeReturnButton('),
        reason: 'No root-safe return on $path',
      );
    }
  });
}
