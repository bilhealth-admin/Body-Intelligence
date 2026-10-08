import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('friend acceptance is a durable attention event', () {
    final attention = File(
      'lib/features/community/domain/community_attention.dart',
    ).readAsStringSync();
    final scope = File(
      'lib/features/community/presentation/community_attention_scope.dart',
    ).readAsStringSync();
    final page = [
      'lib/features/community/presentation/community_notifications_page.dart',
      'lib/features/community/presentation/community_notifications_rendering.dart',
      // The localized notification titles were extracted from the widget
      // without changing the visible friend-accepted contract.
      'lib/features/community/presentation/community_notifications_title.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    expect(attention, contains('communityUpdates'));
    expect(attention, contains('CommunityNotificationKind.friendAccepted'));
    expect(attention, contains("rewardEarned('reward_earned')"));
    expect(scope, contains("'bil_community_attention_v2'"));
    expect(scope, contains("table: 'bil_community_notifications'"));
    expect(page, contains('accepted your friend request'));
    expect(page, contains('markCommunityNotificationsSeen'));
    expect(page, contains('_notificationTitle'));
    expect(page, contains('_routeFor'));
    expect(page, contains('notifications: persisted.notifications'));
    expect(page, contains('_onAttentionChanged'));
  });
}
