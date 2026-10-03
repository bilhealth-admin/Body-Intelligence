import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _communityRepositorySource() => [
  'lib/features/community/data/community_repository.dart',
  'lib/features/community/data/community_repository_discovery_mixin.dart',
  'lib/features/community/data/community_repository_profile_moderation_mixin.dart',
  'lib/features/community/data/community_repository_reference_parity_mixin.dart',
  'lib/features/community/data/community_repository_publishing_mixin.dart',
  'lib/features/community/data/community_repository_connections_messaging_mixin.dart',
].map((path) => File(path).readAsStringSync()).join('\n');

void main() {
  test('global Community profile is privacy-bounded and server-projected', () {
    final sql = File(
      'supabase/migrations/20261003064812_community_profile_projection_privacy_v1.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('bil_community_profile_projection_v1'));
    expect(sql, contains('bil_community_profile_posts_v1'));
    expect(sql, contains('bil_community_profile_connections_v1'));
    expect(sql, contains('security definer'));
    expect(sql, contains('show_followers'));
    expect(sql, contains('show_following'));
    expect(sql, contains('show_friends'));
    expect(sql, contains('show_posts'));
    expect(sql, contains('show_membership_tier'));
    expect(sql, contains('gold_balance'));
    expect(sql, contains('community_xp'));
    expect(sql, contains('community_level'));
    expect(sql, contains('bil_social_profile_visible_v2'));
    expect(sql, contains('bil_social_post_visible_v2'));
    expect(sql, contains('bil_social_member_visible_v2'));
    expect(sql, contains('revoke all on function'));
    expect(sql, contains('to authenticated'));
    expect(sql, isNot(contains('weight')));
    expect(sql, isNot(contains('waist')));
    expect(sql, isNot(contains('bmi')));
    expect(sql, isNot(contains('bil_subscriptions')));
  });

  test('Flutter profile uses bounded RPCs and authored post pagination', () {
    final repository = _communityRepositorySource();
    final store = File(
      'lib/features/community/data/community_post_cloud_store.dart',
    ).readAsStringSync();
    final mixin = File(
      'lib/features/community/data/community_feed_repository_mixin.dart',
    ).readAsStringSync();
    final account = File(
      'lib/features/community/presentation/community_account_widgets.dart',
    ).readAsStringSync();
    final memberPage = [
      'lib/features/community/presentation/community_member_profile_page.dart',
      'lib/features/community/presentation/community_member_profile_content.dart',
      'lib/features/community/presentation/community_member_profile_header.dart',
      'lib/features/community/presentation/community_member_profile_drafts.dart',
      'lib/features/community/presentation/community_member_profile_creator_widgets.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final router = File('lib/app/router/app_router.dart').readAsStringSync();

    expect(repository, contains('bil_community_profile_projection_v1'));
    expect(repository, contains('bil_community_profile_connections_v2'));
    expect(repository, contains('bil_community_creator_projection_v1'));
    expect(repository, contains('bil_community_profile_reviews_v1'));
    expect(repository, contains('bil_community_post_view_counts_v1'));
    expect(store, contains('bil_community_profile_posts_v1'));
    expect(mixin, contains('loadProfilePosts'));
    expect(account, contains('BIL Gold'));
    expect(account, contains('Community XP'));
    expect(memberPage, contains('CommunityMemberProfilePage'));
    expect(memberPage, contains('_CommunityProfilePostTile'));
    expect(memberPage, contains('CommunityProfileConnectionKind.followers'));
    expect(memberPage, contains('CommunityProfileConnectionKind.following'));
    expect(memberPage, contains('CommunityProfileConnectionKind.friends'));
    expect(router, contains("path: '/community/profile/:userId'"));
  });

  test('profile privacy controls are explicit and membership is opt-in', () {
    final page = File(
      'lib/features/community/presentation/community_profile_page.dart',
    ).readAsStringSync();
    final models = File(
      'lib/features/community/domain/community_models.dart',
    ).readAsStringSync();

    expect(page, contains('community-profile-show-posts'));
    expect(page, contains('community-profile-show-friends'));
    expect(page, contains('community-profile-show-followers'));
    expect(page, contains('community-profile-show-following'));
    expect(page, contains('community-profile-show-membership-tier'));
    expect(page, contains('saveMyProfilePrivacy'));
    expect(models, contains('this.showMembershipTier = false'));
  });
}
