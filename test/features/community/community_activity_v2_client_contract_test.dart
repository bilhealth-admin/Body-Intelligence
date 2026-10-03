import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _communityRepositorySource() => [
  'lib/features/community/data/community_repository.dart',
  'lib/features/community/data/community_repository_discovery_mixin.dart',
  'lib/features/community/data/community_repository_profile_moderation_mixin.dart',
  'lib/features/community/data/community_repository_publishing_mixin.dart',
  'lib/features/community/data/community_repository_connections_messaging_mixin.dart',
].map((path) => File(path).readAsStringSync()).join('\n');

void main() {
  test(
    'Flutter consumes Activity v2 while retaining injected repository seams',
    () {
      final repository = _communityRepositorySource();
      final social = File(
        'lib/features/community/data/community_social_repository_mixin.dart',
      ).readAsStringSync();
      final scope = File(
        'lib/features/community/presentation/community_attention_scope.dart',
      ).readAsStringSync();
      final page = File(
        'lib/features/community/presentation/community_notifications_page.dart',
      ).readAsStringSync();

      expect(repository, contains('bil_list_community_activity_v2'));
      expect(repository, contains('bil_mark_community_activity_seen_v2'));
      expect(social, contains('bil_community_attention_v2'));
      expect(scope, contains('bil_community_attention_v2'));
      expect(page, contains('CommunityNotificationKind.rewardEarned'));
      expect(page, contains('CommunityNotificationKind.questCompleted'));
      expect(page, contains('CommunityNotificationKind.mention'));
      expect(page, contains("'/community/rewards'"));
      expect(page, contains('CommunityNotificationKind.badgeEarned'));
      expect(page, contains('CommunityNotificationKind.challengeUpdate'));
      expect(page, isNot(contains('context.push(notification.deepLinkPath)')));
    },
  );
}
