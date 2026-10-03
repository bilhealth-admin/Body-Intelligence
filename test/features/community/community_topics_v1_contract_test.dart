import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('topics foundation is server-authoritative and privacy bounded', () {
    final sql = File(
      'supabase/migrations/20261003085331_community_topics_foundation_v1.sql',
    ).readAsStringSync();

    expect(sql, contains('create table public.bil_community_topics'));
    expect(sql, contains('create table public.bil_community_topic_follows'));
    expect(sql, contains('create table public.bil_community_post_topics'));
    expect(sql, contains('bil_list_community_topics_v1'));
    expect(sql, contains('bil_follow_community_topic_v1'));
    expect(sql, contains('bil_set_my_community_post_topics_v1'));
    expect(sql, contains('bil_community_topic_post_refs_v1'));
    expect(sql, contains('cardinality(p_slugs)>3'));
    expect(sql, contains('community_topic_follow_limit'));
    expect(sql, contains('public.bil_social_post_visible_v2'));
    expect(sql, contains('enable row level security'));
    expect(sql, contains('revoke all on table public.bil_community_topics'));
    expect(sql, isNot(contains('weight_kg')));
    expect(sql, isNot(contains('health_data')));
  });

  test('topic payload parser rejects invented or malformed counts', () {
    final topic = CommunityTopic.fromJson({
      'slug': 'nutrition',
      'title_copy_key': 'community_topic_nutrition',
      'description_copy_key': 'community_topic_nutrition_body',
      'icon_key': 'nutrition',
      'featured': true,
      'follower_count': 12,
      'post_count': 34,
      'following': false,
    });
    expect(topic.slug, 'nutrition');
    expect(topic.postCount, 34);

    expect(
      () => CommunityTopic.fromJson({
        'slug': 'nutrition',
        'title_copy_key': 'community_topic_nutrition',
        'description_copy_key': 'community_topic_nutrition_body',
        'icon_key': 'nutrition',
        'featured': true,
        'follower_count': -1,
        'post_count': 34,
        'following': false,
      }),
      throwsFormatException,
    );
  });

  test(
    'Flutter topics use real RPC counts and explicit composer assignment',
    () {
      final repository = File(
        'lib/features/community/data/community_repository.dart',
      ).readAsStringSync();
      final store = File(
        'lib/features/community/data/community_post_cloud_store.dart',
      ).readAsStringSync();
      final composer = File(
        'lib/features/community/presentation/community_post_composer_page.dart',
      ).readAsStringSync();
      final topics = File(
        'lib/features/community/presentation/community_topics_page.dart',
      ).readAsStringSync();
      final hub = File(
        'lib/features/community/presentation/community_hub_page.dart',
      ).readAsStringSync();

      expect(repository, contains('bil_list_community_topics_v1'));
      expect(repository, contains('bil_follow_community_topic_v1'));
      expect(repository, contains('bil_set_my_community_post_topics_v1'));
      expect(repository, contains('bil_community_topic_post_refs_v1'));
      expect(store, contains('CommunityPostPublishingReceiptContract'));
      expect(store, contains('publishTextWithReceipt'));
      expect(store, contains('publishWithImageReceipt'));
      expect(composer, contains('community-composer-topic-'));
      expect(composer, contains('topicSlugs: topicSlugs'));
      expect(topics, contains('community-topics-list'));
      expect(topics, contains('followerCount'));
      expect(topics, contains('postCount'));
      expect(hub, contains("part 'community_topics_page.dart';"));
    },
  );
}
