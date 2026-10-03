import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:flutter_test/flutter_test.dart';

String _communityRepositorySource() => [
  'lib/features/community/data/community_repository.dart',
  'lib/features/community/data/community_repository_discovery_mixin.dart',
  'lib/features/community/data/community_repository_profile_moderation_mixin.dart',
  'lib/features/community/data/community_repository_publishing_mixin.dart',
  'lib/features/community/data/community_repository_connections_messaging_mixin.dart',
].map((path) => File(path).readAsStringSync()).join('\n');

void main() {
  test('circles foundation is server-authoritative and membership bounded', () {
    final sql = File(
      'supabase/migrations/20261003091136_community_circles_foundation_v1.sql',
    ).readAsStringSync();

    expect(sql, contains('create table public.bil_community_circles'));
    expect(
      sql,
      contains('create table public.bil_community_circle_memberships'),
    );
    expect(sql, contains('create table public.bil_community_post_circles'));
    expect(sql, contains('bil_list_community_circles_v1'));
    expect(sql, contains('bil_join_community_circle_v1'));
    expect(sql, contains('bil_leave_community_circle_v1'));
    expect(sql, contains('bil_set_my_community_post_circle_v1'));
    expect(sql, contains('bil_community_circle_post_refs_v1'));
    expect(sql, contains('community_circle_membership_limit'));
    expect(sql, contains('community_circle_membership_required'));
    expect(sql, contains('public.bil_social_post_visible_v2'));
    expect(sql, contains('enable row level security'));
    expect(sql, isNot(contains('weight_kg')));
    expect(sql, isNot(contains('waist')));
    expect(sql, isNot(contains('health_data')));
  });

  test('circle parser keeps membership and counts explicit', () {
    final circle = CommunityCircle.fromJson({
      'slug': '10k-steps',
      'title_copy_key': 'community_circle_10k_steps',
      'description_copy_key': 'community_circle_10k_steps_body',
      'rules_copy_key': 'community_circle_standard_rules',
      'access': 'public',
      'join_policy': 'open',
      'featured': true,
      'member_count': 12,
      'post_count': 8,
      'membership_status': 'active',
      'membership_role': 'member',
    });

    expect(circle.activeMember, isTrue);
    expect(circle.memberCount, 12);
    expect(circle.postCount, 8);

    expect(
      () => CommunityCircle.fromJson({
        'slug': '10k-steps',
        'title_copy_key': 'community_circle_10k_steps',
        'description_copy_key': 'community_circle_10k_steps_body',
        'rules_copy_key': 'community_circle_standard_rules',
        'access': 'public',
        'join_policy': 'open',
        'featured': true,
        'member_count': -1,
        'post_count': 8,
        'membership_status': null,
        'membership_role': null,
      }),
      throwsFormatException,
    );
  });

  test('Flutter circles expose real membership, feed, and composer contracts', () {
    final repository = _communityRepositorySource();
    final mixin = File(
      'lib/features/community/data/community_feed_repository_mixin.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/community/presentation/community_circles_page.dart',
    ).readAsStringSync();
    final composer = [
      'lib/features/community/presentation/community_post_composer_page.dart',
      'lib/features/community/presentation/community_post_composer_rendering.dart',
      'lib/features/community/presentation/community_post_composer_reference_sections.dart',
      'lib/features/community/presentation/community_post_composer_reference_actions.dart',
      'lib/features/community/presentation/community_post_composer_toolbar.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final hub = File(
      'lib/features/community/presentation/community_hub_page.dart',
    ).readAsStringSync();

    expect(repository, contains('bil_list_community_circles_v1'));
    expect(repository, contains('bil_join_community_circle_v1'));
    expect(repository, contains('bil_leave_community_circle_v1'));
    expect(repository, contains('bil_set_my_community_post_circle_v1'));
    expect(repository, contains('bil_community_circle_post_refs_v1'));
    expect(repository, contains('publishPostWithTopicsAndCircle'));
    expect(repository, contains('publishPostWithImageTopicsAndCircle'));
    expect(mixin, contains('loadCommunityCirclePosts'));
    expect(page, contains('community-circles-list'));
    expect(page, contains('community-circle-membership-'));
    expect(composer, contains('community-composer-circle-'));
    expect(hub, contains("part 'community_circles_page.dart';"));
    expect(hub, contains("case 'circles':"));
  });
}
