import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Activity inbox matches reference filters and keeps safe routes', () {
    final page = File(
      'lib/features/community/presentation/community_notifications_page.dart',
    ).readAsStringSync();
    final filters = File(
      'lib/features/community/presentation/community_notifications_filters.dart',
    ).readAsStringSync();

    expect(page, contains('enum _ActivityFilter { updates, reactions, comments, followers }'));
    expect(page, contains('community-activity-filter-'));
    expect(filters, contains('_ActivityFilter.updates'));
    expect(filters, contains('_ActivityFilter.reactions'));
    expect(filters, contains('_ActivityFilter.comments'));
    expect(filters, contains('_ActivityFilter.followers'));
    expect(filters, contains("'Updates'"));
    expect(filters, contains("'Likes & saves'"));
    expect(filters, contains("'Comments'"));
    expect(filters, contains("'New followers'"));
    expect(filters, contains('CommunityNotificationKind.collaborationInvite'));
    expect(filters, contains('CommunityNotificationKind.collaborationAccepted'));
    expect(filters, contains('CommunityNotificationKind.follow'));
    expect(page, contains("'/community/profile/\${notification.actorId}'"));
    expect(page, contains('CommunityNotificationKind.collaborationInvite'));
    expect(page, contains('CommunityNotificationKind.collaborationAccepted'));
    expect(page, isNot(contains('context.push(notification.deepLinkPath)')));
  });
}
