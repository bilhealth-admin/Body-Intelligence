import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Activity inbox matches reference filters and keeps safe routes', () {
    final page = [
      'lib/features/community/presentation/community_notifications_page.dart',
      'lib/features/community/presentation/community_notifications_rendering.dart',
      'lib/features/community/presentation/community_notifications_reference_widgets.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final filters = File(
      'lib/features/community/presentation/community_notifications_filters.dart',
    ).readAsStringSync();

    expect(
      page,
      contains(
        'enum _ActivityFilter { all, updates, reactions, comments, followers }',
      ),
    );
    expect(page, contains('community-activity-filter-'));
    expect(filters, contains('_ActivityFilter.all => null'));
    expect(filters, contains('_ActivityFilter.all => true'));
    expect(filters, contains('_ActivityFilter.updates'));
    expect(filters, contains('_ActivityFilter.reactions'));
    expect(filters, contains('_ActivityFilter.comments'));
    expect(filters, contains('_ActivityFilter.followers'));
    expect(filters, contains("'Approvals'"));
    expect(filters, contains("'Mentions'"));
    expect(filters, contains("'Comments'"));
    expect(filters, contains("'Followers'"));
    expect(page, contains('CommunityNotificationKind.collaborationInvite'));
    expect(page, contains('_notificationTrailing(notification)'));
    expect(page, contains(r'community-collab-accept-${notification.id}'));
    expect(page, contains(r'community-collab-decline-${notification.id}'));
    expect(
      filters,
      contains('CommunityNotificationKind.collaborationAccepted'),
    );
    expect(filters, contains('CommunityNotificationKind.follow'));
    expect(page, contains("'/community/profile/\${notification.actorId}'"));
    expect(
      page,
      contains("part 'community_notifications_reference_widgets.dart';"),
    );
    expect(page, contains('CommunityNotificationKind.collaborationAccepted'));
    expect(page, isNot(contains('context.push(notification.deepLinkPath)')));
  });
}
