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
    final page = File(
      'lib/features/community/presentation/community_notifications_page.dart',
    ).readAsStringSync();
    expect(attention, contains('communityUpdates'));
    expect(attention, contains('CommunityNotificationKind.friendAccepted'));
    expect(scope, contains("table: 'bil_community_notifications'"));
    expect(page, contains('accepted your friend request'));
    expect(page, contains('markCommunityNotificationsSeen'));
  });
}
