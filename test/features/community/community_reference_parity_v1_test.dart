import 'dart:io';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_reference_parity.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _viewer = '11111111-1111-4111-8111-111111111111';
const _creatorId = '22222222-2222-4222-8222-222222222222';
const _postId = '33333333-3333-4333-8333-333333333333';
const _reviewId = '44444444-4444-4444-8444-444444444444';

class _ReferenceParityRepository extends CommunityRepository {
  _ReferenceParityRepository()
    : super(
        SupabaseClient(
          'https://community-reference.invalid',
          'reference-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  bool following = false;
  int followCalls = 0;
  int unfollowCalls = 0;
  int viewCalls = 0;

  @override
  bool get useServerCommunityReferenceParity => true;

  @override
  String get currentUserId => _viewer;

  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async =>
      CommunityProfileOverview(
        userId: _creatorId,
        displayName: 'BIL Creator',
        isSelf: false,
        relationship: CommunityRelationshipStatus.none,
        allowFriendRequests: true,
        allowFollows: true,
        showFollowers: true,
        showFollowing: true,
        showFriends: true,
        showPosts: true,
        showMembershipTier: false,
        handle: 'bil_creator',
        followerCount: following ? 13 : 12,
        followingCount: 6,
        friendCount: 4,
        postCount: 8,
        communityXp: 900,
        communityLevel: 4,
        communityLevelCopyKey: 'community_level_4',
        currentLevelMinXp: 700,
        nextCommunityLevel: 5,
        nextLevelMinXp: 1500,
        viewerFollows: following,
        followsViewer: true,
      );

  @override
  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async => CommunityFeedBatch(
    posts: [
      CommunityPost(
        id: _postId,
        authorId: _creatorId,
        authorName: 'BIL Creator',
        authorHandle: 'bil_creator',
        body: 'A verified Community moment.',
        createdAt: DateTime.utc(2026, 10, 3, 12),
        moderationStatus: CommunityPostModerationStatus.approved,
        likeCount: 21,
        commentCount: 5,
      ),
    ],
    hasMore: false,
  );

  @override
  Future<CommunityCreatorProfile> loadCommunityCreatorProfile(
    String userId,
  ) async => CommunityCreatorProfile(
    userId: _creatorId,
    contributor: true,
    approvedPosts: 8,
    followers: following ? 13 : 12,
    likesReceived: 41,
    commentsReceived: 18,
    qualifiedReferrals: 2,
    communityXp: 900,
    communityLevel: 4,
    currentLevelMinXp: 700,
    nextCommunityLevel: 5,
    nextLevelMinXp: 1500,
    earnedBadgeCount: 2,
    totalBadgeCount: 7,
    badges: const [
      CommunityCreatorBadge(badgeKey: 'profile_complete', earned: true),
      CommunityCreatorBadge(badgeKey: 'first_moment', earned: true),
      CommunityCreatorBadge(badgeKey: 'contributor', earned: false),
      CommunityCreatorBadge(badgeKey: 'conversation_starter', earned: false),
      CommunityCreatorBadge(badgeKey: 'appreciated', earned: false),
      CommunityCreatorBadge(badgeKey: 'connector', earned: false),
      CommunityCreatorBadge(badgeKey: 'referral_builder', earned: false),
    ],
    certificationStatus: CommunityCreatorCertificationStatus.notCertified,
  );

  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> postIds,
  ) async => const {_postId: 37};

  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> postIds) async => [
    const CommunityPostReferenceMetadata(
      postId: _postId,
      title: 'Verified reference title',
      hashtags: ['bilcommunity'],
      topics: [
        CommunityPostTopicReference(
          slug: 'nutrition',
          titleCopyKey: 'community_topic_nutrition',
          postCount: 18,
        ),
      ],
      collaborators: [],
    ),
  ];

  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> postIds) async => [
    CommunityPostReferenceMetadata(
      postId: _postId,
      title: 'Reference title',
      hashtags: const ['progress'],
      collaborators: const <CommunityPostCollaborator>[],
    ),
  ];

  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async => const <CommunityDraftSummary>[];

  @override
  Future<List<CommunityProfileReview>> loadCommunityProfileReviews({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async => [
    CommunityProfileReview(
      reviewId: _reviewId,
      productKind: 'food',
      canonicalName: 'BIL Reference Food',
      brand: 'BIL QA',
      reviewNote: 'Approved public review text.',
      createdAt: DateTime.utc(2026, 10, 2),
    ),
  ];

  @override
  Future<void> follow(String userId) async {
    expect(userId, _creatorId);
    followCalls++;
    following = true;
  }

  @override
  Future<void> unfollow(String userId) async {
    expect(userId, _creatorId);
    unfollowCalls++;
    following = false;
  }

  @override
  Future<int> recordCommunityPostView(String postId) async {
    expect(postId, _postId);
    viewCalls++;
    return 38;
  }
}

void main() {
  test('reference parity migration is authoritative and privacy bounded', () {
    final sql = File(
      'supabase/migrations/20261003210000_community_reference_profile_creator_v1.sql',
    ).readAsStringSync().toLowerCase();

    for (final required in const [
      'bil_community_post_views_v1',
      'bil_record_community_post_view_v1',
      'bil_community_post_view_counts_v1',
      'bil_community_profile_connections_v2',
      'viewer_follows',
      'follows_viewer',
      'bil_community_creator_projection_v1',
      'current_level_min_xp',
      'next_level_min_xp',
      'bil_community_profile_reviews_v1',
      'bil_community_creator_certifications_v1',
      'security definer',
      "set search_path=''",
      'revoke all on table',
      'to authenticated',
    ]) {
      expect(sql, contains(required), reason: required);
    }

    for (final forbidden in const [
      'weight',
      'waist',
      'bmi',
      'body_fat',
      'health_log',
      'bil_subscriptions',
    ]) {
      expect(sql, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('creator projection parses badge and level progress strictly', () {
    final projection = CommunityCreatorProfile.fromJson({
      'user_id': _creatorId,
      'contributor': true,
      'approved_posts': 8,
      'followers': 12,
      'likes_received': 41,
      'comments_received': 18,
      'qualified_referrals': 2,
      'community_xp': 900,
      'community_level': 4,
      'current_level_min_xp': 700,
      'next_community_level': 5,
      'next_level_min_xp': 1500,
      'earned_badge_count': 1,
      'total_badge_count': 7,
      'badges': [
        {'badge_key': 'profile_complete', 'earned': true},
        {'badge_key': 'first_moment', 'earned': false},
        {'badge_key': 'contributor', 'earned': false},
        {'badge_key': 'conversation_starter', 'earned': false},
        {'badge_key': 'appreciated', 'earned': false},
        {'badge_key': 'connector', 'earned': false},
        {'badge_key': 'referral_builder', 'earned': false},
      ],
      'certification_status': 'not_certified',
    });

    expect(projection.communityLevel, 4);
    expect(projection.nextCommunityLevel, 5);
    expect(projection.levelProgress, closeTo(.25, .0001));
    expect(projection.badges.where((badge) => badge.earned), hasLength(1));
  });

  test('membership tier and cover remain explicit opt-in boundaries', () {
    final tier = File(
      'supabase/migrations/20261003212500_community_comment_membership_tier_v1.sql',
    ).readAsStringSync().toLowerCase();
    final cover = File(
      'supabase/migrations/20261003213000_community_profile_cover_v1.sql',
    ).readAsStringSync().toLowerCase();

    expect(tier, contains('p.show_membership_tier'));
    expect(tier, contains('bil_has_active_premium'));
    expect(tier, contains("set search_path=''"));
    expect(tier, isNot(contains('weight')));
    expect(tier, isNot(contains('body_fat')));

    expect(cover, contains('cover_object_path'));
    expect(cover, contains('bil_set_my_community_profile_cover_v1'));
    expect(cover, contains('bil_community_profile_cover_v1'));
    expect(cover, contains("bucket_id='profile-avatars'"));
    expect(cover, contains("owner_id=v_uid::text"));
    expect(cover, contains("set search_path=''"));
  });

  testWidgets(
    'profile exposes real Follow, creator badges, views and Reviews',
    (tester) async {
      final repository = _ReferenceParityRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityMemberProfilePage(
            userId: _creatorId,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community-creator-panel')), findsOneWidget);
      expect(
        find.byKey(const Key('community-profile-follow-action')),
        findsOneWidget,
      );
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Follows you'), findsOneWidget);
      expect(find.text('2/7 Badges'), findsOneWidget);
      expect(find.text('37'), findsOneWidget);
      expect(
        find.byKey(const Key('community-profile-tab-moments')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-profile-tab-reviews')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('community-profile-follow-action')),
      );
      await tester.pumpAndSettle();
      expect(repository.followCalls, 1);
      expect(find.text('Following'), findsOneWidget);

      await tester.tap(find.byKey(const Key('community-profile-tab-reviews')));
      await tester.pumpAndSettle();
      expect(find.text('BIL Reference Food'), findsOneWidget);
      expect(find.text('Approved public review text.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('community-creator-badges')));
      await tester.pumpAndSettle();
      expect(find.text('Community badges'), findsOneWidget);
      expect(find.text('Profile complete'), findsOneWidget);
      expect(find.text('Earned'), findsOneWidget);
    },
  );
}
