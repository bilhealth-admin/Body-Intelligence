import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:flutter_test/flutter_test.dart';

String _repositorySource() => [
  'lib/features/community/data/community_repository.dart',
  'lib/features/community/data/community_repository_discovery_mixin.dart',
  'lib/features/community/data/community_repository_profile_moderation_mixin.dart',
  'lib/features/community/data/community_repository_publishing_mixin.dart',
  'lib/features/community/data/community_repository_connections_messaging_mixin.dart',
].map((path) => File(path).readAsStringSync()).join('\n');

void main() {
  test('server feed modes are scoped, ranked, and cursor-bounded', () {
    final sql = File(
      'supabase/migrations/20261003093710_community_feed_modes_v1.sql',
    ).readAsStringSync();

    expect(sql, contains("'for_you','following','friends','explore'"));
    expect(sql, contains('public.bil_social_post_visible_v2'));
    expect(sql, contains('public.bil_follows'));
    expect(sql, contains('public.bil_friendships'));
    expect(sql, contains('public.bil_community_topic_follows'));
    expect(sql, contains('public.bil_community_circle_memberships'));
    expect(sql, contains("then 40 else 0"));
    expect(sql, contains("then 30 else 0"));
    expect(sql, contains("then 20 else 0"));
    expect(sql, contains("then 15 else 0"));
    expect(sql, contains('p_before_priority'));
    expect(sql, contains('order by s.priority desc'));
    expect(
      sql,
      contains('grant execute on function public.bil_community_feed_refs_v1'),
    );
    expect(sql, isNot(contains('service_role to authenticated')));
  });

  test('feed reference parser accepts only bounded reasons and priority', () {
    final ref = CommunityFeedReference.fromJson({
      'post_id': '11111111-1111-4111-8111-111111111111',
      'created_at': '2026-10-03T09:00:00Z',
      'priority': 70,
      'reasons': ['friend', 'followed_author'],
    });
    expect(ref.priority, 70);
    expect(ref.reasons, ['friend', 'followed_author']);

    expect(
      () => CommunityFeedReference.fromJson({
        'post_id': '11111111-1111-4111-8111-111111111111',
        'created_at': '2026-10-03T09:00:00Z',
        'priority': 999,
        'reasons': ['invented_signal'],
      }),
      throwsFormatException,
    );
  });

  test('Flutter feed tabs use server references, not client-side ranking', () {
    final repository = _repositorySource();
    final mixin = File(
      'lib/features/community/data/community_feed_repository_mixin.dart',
    ).readAsStringSync();
    final pagination = File(
      'lib/features/community/presentation/community_feed_pagination.dart',
    ).readAsStringSync();
    final feed = [
      'lib/features/community/presentation/community_feed_tab.dart',
      'lib/features/community/presentation/community_feed_mode_control.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(repository, contains('bil_community_feed_refs_v1'));
    expect(mixin, contains('loadCommunityFeedMode'));
    expect(pagination, contains('beforePriority: _feedCursorPriority'));
    expect(feed, contains('CommunityFeedMode.forYou'));
    expect(feed, contains('CommunityFeedMode.following'));
    expect(feed, contains('CommunityFeedMode.friends'));
    expect(feed, contains('CommunityFeedMode.explore'));
    expect(feed, contains('community-feed-mode-'));
    expect(feed, isNot(contains('sort((a, b)')));
  });
}
