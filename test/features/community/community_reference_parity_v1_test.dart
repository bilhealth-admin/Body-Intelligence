import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_community_reference.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_reference_parity.dart';
import 'package:body_intelligence_log/features/community/domain/community_rewards.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _viewer = '11111111-1111-4111-8111-111111111111';
const _creatorId = '22222222-2222-4222-8222-222222222222';
const _postId = '33333333-3333-4333-8333-333333333333';
const _reviewId = '44444444-4444-4444-8444-444444444444';

class _ReferenceParityRepository extends CommunityRepository {
  _ReferenceParityRepository({this.selfProfile = false})
    : super(
        SupabaseClient(
          'https://community-reference.invalid',
          'reference-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final bool selfProfile;

  bool following = false;
  int followCalls = 0;
  int unfollowCalls = 0;
  int viewCalls = 0;

  @override
  bool get useServerCommunityReferenceParity => true;

  @override
  String get currentUserId => selfProfile ? _creatorId : _viewer;

  @override
  Future<CommunityGoldBalance> loadGoldBalance() async =>
      throw StateError('Synthetic rewards unavailable');

  @override
  Future<List<CommunityQuest>> loadCommunityQuests() async => [];

  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async =>
      CommunityProfileOverview(
        userId: _creatorId,
        displayName: 'BIL Creator',
        isSelf: selfProfile,
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
  Future<String?> loadCommunityProfileCoverUrl(String userId) async => null;

  @override
  Future<int> recordCommunityPostView(String postId) async {
    expect(postId, _postId);
    viewCalls++;
    return 38;
  }
}

void main() {
  test('reference Community copy closes every production locale', () {
    expect(CommunityReferenceRuntimeCopy.sources, hasLength(88));
    expect(CommunityReferenceRuntimeCopy.supported, hasLength(23));
    expect(CommunityReferenceRuntimeCopy.balanced, isTrue);
    expect(
      CommunityReferenceRuntimeCopy.supported,
      BilLocalePolicy.productionTags
          .where((tag) => tag != 'en' && tag != 'ar')
          .toSet(),
    );

    for (final tag in CommunityReferenceRuntimeCopy.supported) {
      for (final source in CommunityReferenceRuntimeCopy.sources) {
        final translated = CommunityReferenceRuntimeCopy.resolve(source, tag);
        expect(translated, isNotNull, reason: '$tag: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $source');
        expect(translated, isNot(source), reason: '$tag: $source');
        final expectedPlaceholders = RegExp(
          r'\{[^}]+\}',
        ).allMatches(source).map((match) => match.group(0)).toList();
        final actualPlaceholders = RegExp(
          r'\{[^}]+\}',
        ).allMatches(translated).map((match) => match.group(0)).toList();
        expect(
          actualPlaceholders,
          expectedPlaceholders,
          reason: '$tag: $source',
        );
        if (source.contains('BIL')) {
          expect(translated, contains('BIL'), reason: '$tag: $source');
        }
      }
    }
  });

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
      'body_fat',
      'health_log',
      'bil_subscriptions',
    ]) {
      expect(sql, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(
      RegExp(r'(^|[^a-z0-9_])bmi([^a-z0-9_]|$)').hasMatch(sql),
      isFalse,
      reason: 'bmi identifier',
    );
  });

  test('creator projection parses badge and level progress strictly', () {
    final projection = CommunityCreatorProfile.fromJson({
      'user_id': _creatorId,
      'posts_visible': true,
      'followers_visible': true,
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

    final repository = File(
      'lib/features/community/data/community_repository_reference_parity_mixin.dart',
    ).readAsStringSync();
    final pagination = File(
      'lib/features/community/presentation/community_feed_pagination.dart',
    ).readAsStringSync();
    final card = File(
      'lib/features/community/presentation/community_post_card.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/community/presentation/community_post_detail_page.dart',
    ).readAsStringSync();
    final header = File(
      'lib/features/community/presentation/community_post_detail_header.dart',
    ).readAsStringSync();

    expect(repository, contains('loadVisibleMembershipTiers'));
    expect(repository, contains("'bil_community_comment_membership_tiers_v1'"));
    expect(pagination, contains('loadVisibleMembershipTiers(authorIds)'));
    expect(card, contains('authorMembershipTier'));
    expect(card, contains('_CommunityMembershipTierChip('));
    expect(detail, contains('_loadAuthorMembershipTier'));
    expect(detail, contains('loadVisibleMembershipTiers(['));
    expect(header, contains('authorMembershipTier'));
    expect(header, contains('_CommunityMembershipTierChip('));
  });

  test(
    'feed reference extras stay batched and creator rewards stay authoritative',
    () {
      final previewMigration = File(
        'supabase/migrations/20261004010500_community_feed_comment_previews_v1.sql',
      ).readAsStringSync().toLowerCase();
      final socialRepository = File(
        'lib/features/community/data/community_social_repository_mixin.dart',
      ).readAsStringSync();
      final pagination = File(
        'lib/features/community/presentation/community_feed_pagination.dart',
      ).readAsStringSync();
      final feed = File(
        'lib/features/community/presentation/community_feed_tab.dart',
      ).readAsStringSync();
      final feedSuggestions = File(
        'lib/features/community/presentation/community_feed_reference_suggestions.dart',
      ).readAsStringSync();
      final card = File(
        'lib/features/community/presentation/community_post_card.dart',
      ).readAsStringSync();
      final profile = File(
        'lib/features/community/presentation/community_member_profile_page.dart',
      ).readAsStringSync();
      final creator = File(
        'lib/features/community/presentation/community_member_profile_creator_widgets.dart',
      ).readAsStringSync();
      final hub = File(
        'lib/features/community/presentation/community_hub_page.dart',
      ).readAsStringSync();

      expect(
        previewMigration,
        contains('bil_community_feed_comment_previews_v1'),
      );
      expect(previewMigration, contains('cardinality(p_post_ids) > 100'));
      expect(previewMigration, contains('bil_social_post_visible_v2'));
      expect(previewMigration, contains('bil_social_member_visible_v2'));
      expect(previewMigration, contains('revoke all on function'));
      expect(previewMigration, isNot(contains('grant all on table')));
      expect(
        socialRepository,
        contains("'bil_community_feed_comment_previews_v1'"),
      );
      expect(pagination, contains('loadCommunityFeedCommentPreviews(ids)'));
      expect(feedSuggestions, contains("'community-feed-topic-suggestions'"));
      expect(feed, contains('commentPreview: _commentPreviewByPost[post.id]'));
      expect(card, contains("'community-post-comment-preview-"));
      expect(profile, contains('repository.loadGoldBalance()'));
      expect(profile, contains('repository.loadCommunityQuests()'));
      expect(creator, contains("'community-creator-rewards-snapshot'"));
      expect(creator, contains("'community-creator-gold-balance'"));
      expect(creator, contains("'community-creator-quest-progress'"));
      expect(hub, contains("'community-search'"));
      expect(hub, contains('loadMyProfileOverview()'));
      expect(hub, contains('BilAccountAvatar('));
    },
  );

  test('Community header exposes real search and profile identity entry', () {
    final hub = File(
      'lib/features/community/presentation/community_hub_page.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/features/community/presentation/community_navigation_sheet.dart',
    ).readAsStringSync();

    expect(hub, contains("Key('community-search')"));
    expect(hub, contains("context.push('/community/people')"));
    expect(hub, contains('loadMyProfileOverview()'));
    expect(hub, contains('BilAccountAvatar('));
    expect(hub, contains("Key('community-settings')"));
    expect(navigation, contains("'Community profile'"));
  });

  test('post detail actions and circle cards close reference parity gaps', () {
    final detailActions = File(
      'lib/features/community/presentation/community_post_detail_reference_actions.dart',
    ).readAsStringSync();
    final detailRendering = File(
      'lib/features/community/presentation/community_post_detail_rendering.dart',
    ).readAsStringSync();
    final detailHeader = File(
      'lib/features/community/presentation/community_post_detail_header.dart',
    ).readAsStringSync();
    final circles = File(
      'lib/features/community/presentation/community_circles_page.dart',
    ).readAsStringSync();

    expect(detailActions, contains('setPostSaved('));
    expect(detailActions, contains('SharePlus.instance.share('));
    expect(detailActions, contains("action == 'delete'"));
    expect(detailActions, contains("action == 'block'"));
    expect(detailActions, contains("action == 'report'"));
    expect(detailActions, contains("targetKind: 'post'"));
    expect(detailRendering, contains('saved: _savedPost'));
    expect(detailRendering, contains('_CommunityPostDetailReferenceActions('));
    expect(detailRendering, contains('._togglePostSaved()'));
    expect(detailRendering, contains('._sharePost(anchorContext)'));
    expect(detailHeader, contains("Key('community-post-detail-save')"));
    expect(detailHeader, contains("Key('community-post-detail-share')"));
    expect(detailHeader, contains("Key('community-post-detail-actions')"));
    expect(detailHeader, contains("value: 'delete'"));
    expect(detailHeader, contains("value: 'report'"));
    expect(detailHeader, contains("value: 'block'"));
    expect(detailHeader, contains('Wrap('));
    expect(circles, contains("Key('community-circle-cover-\$slug')"));
    expect(circles, contains('_CommunityCircleCover(slug: circle.slug)'));
    expect(circles, contains('final headerAction ='));
    expect(circles, contains("'community-circle-membership-\${circle.slug}'"));
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
      await tester.tap(
        find.byKey(const Key('community-profile-follow-action')),
      );
      await tester.pumpAndSettle();
      expect(repository.followCalls, 1);
      expect(
        find.descendant(
          of: find.byKey(const Key('community-profile-follow-action')),
          matching: find.text('Following'),
        ),
        findsOneWidget,
      );

      final momentsTab = find.byKey(const Key('community-profile-tab-moments'));
      await tester.scrollUntilVisible(
        momentsTab,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(momentsTab, findsOneWidget);
      expect(
        find.byKey(const Key('community-profile-tab-reviews')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('community-profile-tab-reviews')));
      await tester.pumpAndSettle();
      expect(find.text('BIL Reference Food'), findsOneWidget);
      expect(find.text('Approved public review text.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('community-creator-badges')));
      await tester.pumpAndSettle();
      expect(find.text('Community badges'), findsOneWidget);
      expect(find.text('Profile complete'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('community-creator-badge-profile_complete')),
          matching: find.text('Earned'),
        ),
        findsOneWidget,
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('community-profile-tab-moments')));
      await tester.pumpAndSettle();
      final viewCount = find.byKey(
        const Key('community-profile-post-views-$_postId'),
      );
      await tester.scrollUntilVisible(
        viewCount,
        280,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(viewCount, findsOneWidget);
      expect(tester.widget<Text>(viewCount).data, '37');
    },
  );

  for (final language in ['en', 'ar']) {
    testWidgets('moment filters wrap and remain usable at 200% in $language', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: CommunityMemberProfilePage(
            userId: _creatorId,
            repository: _ReferenceParityRepository(selfProfile: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final filter = find.byKey(const Key('community-profile-moment-filter'));
      await tester.scrollUntilVisible(
        filter,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(filter);
      await tester.pumpAndSettle();
      expect(filter.hitTestable(), findsOneWidget);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      final pending = find
          .text(language == 'ar' ? 'قيد الانتظار' : 'Pending')
          .last;
      await tester.ensureVisible(pending);
      await tester.pumpAndSettle();
      expect(
        tester.renderObject<RenderParagraph>(pending).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(pending);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: filter,
          matching: find.text(language == 'ar' ? 'قيد الانتظار' : 'Pending'),
        ),
        findsOneWidget,
      );
      expect(find.text('A verified Community moment.'), findsNothing);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      final published = find
          .text(language == 'ar' ? 'منشور' : 'Published')
          .last;
      await tester.ensureVisible(published);
      await tester.tap(published);
      await tester.pumpAndSettle();
      final views = find.byKey(
        const Key('community-profile-post-views-$_postId'),
      );
      await tester.scrollUntilVisible(
        views,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<Text>(views).data, '37');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'creator center metrics remain reachable on 320x568 at 200% in $language',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: CommunityMemberProfilePage(
              userId: _creatorId,
              repository: _ReferenceParityRepository(selfProfile: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final stats = find.byKey(const Key('community-self-stats'));
        await tester.scrollUntilVisible(
          stats,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(stats);
        await tester.pumpAndSettle();
        expect(stats.hitTestable(), findsOneWidget);
        await tester.tap(stats);
        await tester.pumpAndSettle();
        final center = find.byKey(const Key('community-creator-center'));
        await tester.scrollUntilVisible(
          center,
          160,
          scrollable: find
              .descendant(
                of: find.byType(BottomSheet).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(center);
        await tester.pumpAndSettle();
        expect(tester.getSize(center).height, greaterThanOrEqualTo(48));
        final label = find.descendant(of: center, matching: find.byType(Text));
        expect(
          tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
          isFalse,
          reason: 'Creator tool meaning must not be truncated at 200%',
        );
        await tester.tap(center);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final lastMetric = find.text(
          language == 'ar' ? 'الدعوات المؤهلة' : 'Qualified referrals',
        );
        await tester.ensureVisible(lastMetric);
        await tester.pumpAndSettle();
        expect(lastMetric, findsOneWidget);
        expect(tester.getRect(lastMetric).bottom, lessThanOrEqualTo(568));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'all creator badges are reachable on 320x568 at 200% in $language',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: CommunityMemberProfilePage(
              userId: _creatorId,
              repository: _ReferenceParityRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final badges = find.byKey(const Key('community-creator-badges'));
        await tester.scrollUntilVisible(
          badges,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(badges);
        await tester.pumpAndSettle();
        await tester.tap(badges);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final lastBadge = find.byKey(
          const Key('community-creator-badge-referral_builder'),
        );
        await tester.ensureVisible(lastBadge);
        await tester.pumpAndSettle();
        expect(tester.getRect(lastBadge).bottom, lessThanOrEqualTo(568));
        expect(tester.getRect(lastBadge).top, greaterThanOrEqualTo(0));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
