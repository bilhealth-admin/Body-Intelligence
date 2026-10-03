import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Activity inbox exposes explicit social filters and safe routes', () {
    final page = File(
      'lib/features/community/presentation/community_notifications_page.dart',
    ).readAsStringSync();

    expect(page, contains('enum _ActivityFilter'));
    expect(page, contains('_ActivityFilter.friends'));
    expect(page, contains('_ActivityFilter.reactions'));
    expect(page, contains('_ActivityFilter.comments'));
    expect(page, contains('_ActivityFilter.rewards'));
    expect(page, contains('community-activity-filter-'));
    expect(
      page,
      contains(
        "CommunityNotificationKind.postLike ||\n"
        "      CommunityNotificationKind.postSave ||\n"
        "      CommunityNotificationKind.comment ||\n"
        "      CommunityNotificationKind.reply => '/community'",
      ),
    );
    expect(
      page,
      contains(
        "CommunityNotificationKind.rewardEarned ||\n"
        "      CommunityNotificationKind.questCompleted => '/community/rewards'",
      ),
    );
    expect(page, contains("'/community/profile/\${notification.actorId}'"));
    expect(page, isNot(contains('context.push(notification.deepLinkPath)')));
  });
}
