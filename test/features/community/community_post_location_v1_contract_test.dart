import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('post location is a manual label, never GPS coordinates', () {
    final sql = File(
      'supabase/migrations/20261003104726_community_post_location_foundation_v1.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create table public.bil_community_post_locations_v1'),
    );
    expect(sql, contains('bil_set_my_community_post_location_v1'));
    expect(sql, contains('bil_community_post_locations_v1'));
    expect(sql, contains("p.moderation_status='pending'"));
    expect(sql, contains('public.bil_assert_community_publish_ready()'));
    expect(sql, contains('char_length(label) between 2 and 80'));
    expect(sql, contains('enable row level security'));
    expect(sql, isNot(contains('latitude')));
    expect(sql, isNot(contains('longitude')));
    expect(sql, isNot(contains('geography')));
    expect(sql, isNot(contains('geometry')));
  });

  test('post copies preserve optional location labels', () {
    final post = CommunityPost(
      id: '11111111-1111-4111-8111-111111111111',
      authorId: '22222222-2222-4222-8222-222222222222',
      body: 'A post',
      createdAt: DateTime.utc(2026, 10, 3),
      locationLabel: 'Cairo, Egypt',
    );

    expect(post.withSaved(true).locationLabel, 'Cairo, Egypt');
    expect(post.withPoll(null).locationLabel, 'Cairo, Egypt');
    expect(post.withMedia(const []).locationLabel, 'Cairo, Egypt');
    expect(post.withLocation(null).locationLabel, isNull);
  });

  test('cloud feed hydrates location and composer keeps it explicit', () {
    final repository = File(
      'lib/features/community/data/community_repository.dart',
    ).readAsStringSync();
    final feedMixin = File(
      'lib/features/community/data/community_feed_repository_mixin.dart',
    ).readAsStringSync();
    final composer = File(
      'lib/features/community/presentation/community_post_composer_page.dart',
    ).readAsStringSync();
    final card = File(
      'lib/features/community/presentation/community_post_card.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/community/presentation/community_post_detail_page.dart',
    ).readAsStringSync();

    expect(repository, contains('bil_set_my_community_post_location_v1'));
    expect(repository, contains('bil_community_post_locations_v1'));
    expect(feedMixin, contains('loadCommunityPostLocations(postIds)'));
    expect(feedMixin, contains('withLocation(locations[post.id])'));
    expect(composer, contains('community-composer-location-label'));
    expect(
      composer,
      contains('BIL does not attach GPS coordinates to this post.'),
    );
    expect(composer, contains('locationLabel: locationLabel'));
    expect(card, contains('community-post-location-'));
    expect(detail, contains('community-post-detail-location'));
  });
}
