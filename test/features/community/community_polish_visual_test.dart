import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_reference_parity.dart';
import 'package:body_intelligence_log/features/community/domain/community_rewards.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_attention_scope.dart';
import 'package:body_intelligence_log/features/community/presentation/community_connections_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';
import 'package:body_intelligence_log/features/community/presentation/community_profile_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_rewards_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_bil_code_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notifications_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_safety_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../visual_closure/visual_evidence_font.dart';

/// Synthetic profiles only. These scenes never connect to production or send.
class _VisualRepository extends CommunityRepository {
  _VisualRepository(this.arabic)
    : super(
        SupabaseClient(
          'https://visual.invalid',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final bool arabic;
  static const owner = '11111111-1111-4111-8111-111111111111';
  static const peer = '22222222-2222-4222-8222-222222222222';
  String get name => arabic ? 'عضو تجريبي' : 'Sample member';
  @override
  String get currentUserId => owner;
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<CommunityProfile?> loadMyProfile() async => CommunityProfile(
    userId: owner,
    displayName: name,
    localeCode: arabic ? 'ar' : 'en',
    discoverable: true,
    bio: arabic
        ? 'أشارك خطوات رحلتي مع أصدقائي.'
        : 'Sharing small steps with my friends.',
  );
  @override
  Future<CommunitySocialIdentity> loadSocialIdentity() async =>
      const CommunitySocialIdentity(
        handle: 'sample_member',
        chosen: true,
        discoverable: true,
      );
  @override
  Future<CommunityPublicCode> loadPublicCode() async => CommunityPublicCode(
    code: '11111111111141118111111111111111',
    uri: Uri.parse('bil://community/member/11111111111141118111111111111111'),
    handle: 'sample_member',
  );
  @override
  Future<CommunityAttention> loadAttention() async => const CommunityAttention(
    unreadMessages: 3,
    incomingRequests: 1,
    unreadBySender: {peer: 3},
  );
  @override
  Future<CommunityFeedBatch> loadMyPosts({
    DateTime? before,
    String? beforeId,
    int limit = 40,
  }) async => CommunityFeedBatch(
    posts: [
      CommunityPost(
        id: '88888888-8888-4888-8888-888888888888',
        authorId: owner,
        authorName: name,
        authorHandle: 'sample_member',
        body: arabic ? 'يوم جديد وخطوة جديدة.' : 'A new day and a new step.',
        createdAt: DateTime.utc(2026, 9, 29, 8),
        moderationStatus: CommunityPostModerationStatus.pending,
      ),
    ],
    hasMore: false,
  );
  @override
  Future<CommunitySavedPostBatch> loadSavedPosts({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async => CommunitySavedPostBatch(
    posts: (await loadFeed()).map((p) => p.withSaved(true)).toList(),
    hasMore: false,
  );
  @override
  Future<List<CommunityPostStats>> loadPostStats(List<String> ids) async => [
    for (final id in ids)
      CommunityPostStats(
        postId: id,
        likeCount: 4,
        liked: false,
        commentCount: 1,
      ),
  ];
  @override
  Future<List<CommunityComment>> loadPostComments(
    String postId, {
    DateTime? after,
    String? afterId,
    int limit = 30,
  }) async => [
    CommunityComment(
      id: 'fixture-comment',
      authorId: peer,
      authorName: name,
      authorHandle: 'sample_member',
      body: arabic
          ? 'شكرًا على المشاركة والتشجيع!'
          : 'Thanks for sharing and encouraging everyone!',
      createdAt: DateTime.utc(2026, 9, 29, 8, 15),
      likeCount: 0,
      liked: false,
    ),
  ];

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    final policy = CommunityContentPolicy.fromJson({
      'version': 'community-policy-v1',
      'locale_code': localeCode,
      'document_url': 'https://www.bilhealth.com/community-guidelines',
      'effective_at': '2026-09-08T00:00:00Z',
    });
    return CommunityPolicyState.accepted(
      policy,
      acceptedVersion: policy.version,
    );
  }

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => [
    CommunityPost(
      id: '66666666-6666-4666-8666-666666666666',
      authorId: peer,
      authorName: name,
      authorHandle: 'sample_member',
      body: arabic
          ? 'خطوة صغيرة كل يوم تصنع فرقًا. كيف كان يومكم؟'
          : 'Small steps every day make a difference. How was your day?',
      createdAt: DateTime.utc(2026, 9, 29, 8),
      likeCount: 4,
      commentCount: 2,
    ),
    CommunityPost(
      id: '77777777-7777-4777-8777-777777777777',
      authorId: peer,
      authorName: name,
      authorHandle: 'sample_member',
      body: 'A quiet walk and a fresh start.',
      createdAt: DateTime.utc(2026, 9, 28, 8),
      likeCount: 1,
    ),
  ];
  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async => [
    {
      'id': '33333333-3333-4333-8333-333333333333',
      'requester_id': peer,
      'addressee_id': owner,
      'other_user_id': peer,
      'status': 'accepted',
      'profile': {'display_name': name, 'avatar_url': null},
    },
  ];
  Map<String, dynamic> row(bool incoming, int index) => {
    'id': '${index == 0 ? '44444444' : '55555555'}-4444-4444-8444-444444444444',
    'sender_id': incoming ? peer : owner,
    'recipient_id': incoming ? owner : peer,
    'profile': {'display_name': name, 'avatar_url': null},
    'body': arabic
        ? 'أهلًا، شكرًا على التشجيع!'
        : 'Hello, thanks for the encouragement!',
    'created_at': '2026-09-29T08:20:00Z',
    'read_at': index == 0 ? null : '2026-09-29T08:21:00Z',
  };
  @override
  Future<List<Map<String, dynamic>>> loadInboxMessages() async => [
    row(true, 0),
    row(true, 1),
  ];
  @override
  Future<List<Map<String, dynamic>>> loadSentMessages() async => [
    row(false, 0),
  ];
  @override
  Stream<void> watchInboxChanges() => const Stream.empty();
  @override
  Stream<void> watchConversationChanges(String other) => const Stream.empty();
  @override
  Future<List<CommunityMessage>> loadMessages(String other) async => [
    for (var index = 0; index < 4; index++)
      CommunityMessage(
        id: 'synthetic-message-$index',
        senderId: index.isEven ? peer : owner,
        recipientId: index.isEven ? owner : peer,
        body: arabic
            ? 'مرحبًا بك في المجتمع. يوم جميل وخطوة جديدة.'
            : 'Welcome to the community. A good day and a fresh start.',
        createdAt: DateTime.utc(2026, 9, 29, 8, index),
        readAt: DateTime.utc(2026, 9, 29, 8, index + 1),
      ),
  ];
  @override
  Future<int> markVisibleMessagesRead(List<String> ids) async => ids.length;
}

class _FeedReferenceVisualRepository extends _VisualRepository {
  _FeedReferenceVisualRepository(super.arabic);

  @override
  bool get useServerCommunityReferenceParity => true;

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => [
    const CommunityTopic(
      slug: 'success-stories',
      titleCopyKey: 'community_topic_success_stories',
      descriptionCopyKey: 'community_topic_success_stories_body',
      iconKey: 'trophy',
      featured: true,
      followerCount: 184,
      postCount: 42,
      following: false,
    ),
    const CommunityTopic(
      slug: 'nutrition',
      titleCopyKey: 'community_topic_nutrition',
      descriptionCopyKey: 'community_topic_nutrition_body',
      iconKey: 'nutrition',
      featured: true,
      followerCount: 231,
      postCount: 67,
      following: true,
    ),
  ];

  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> postIds) async => [
    for (final postId in postIds)
      CommunityPostReferenceMetadata(
        postId: postId,
        title: arabic ? 'لحظة تستحق المشاركة' : 'A moment worth sharing',
        hashtags: const ['progress'],
        topics: const [
          CommunityPostTopicReference(
            slug: 'success-stories',
            titleCopyKey: 'community_topic_success_stories',
            postCount: 42,
          ),
        ],
        collaborators: const <CommunityPostCollaborator>[],
      ),
  ];

  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> postIds,
  ) async => {for (final postId in postIds) postId: 292};

  @override
  Future<Map<String, CommunityComment>> loadCommunityFeedCommentPreviews(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return const <String, CommunityComment>{};
    return {
      postIds.first: CommunityComment(
        id: 'abababab-abab-4bab-8bab-abababababab',
        authorId: _VisualRepository.peer,
        authorName: name,
        authorHandle: 'sample_member',
        body: arabic
            ? 'استمر، هذه الخطوة الصغيرة مهمة.'
            : 'Keep going — this small step matters.',
        createdAt: DateTime.utc(2026, 9, 29, 8, 15),
        likeCount: 0,
        liked: false,
        replyCount: 4,
      ),
    };
  }
}

class _ReferenceVisualRepository extends _VisualRepository {
  _ReferenceVisualRepository(super.arabic);

  static const profilePost = '99999999-9999-4999-8999-999999999999';
  static const draftId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  @override
  bool get useServerCommunityReferenceParity => true;

  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async {
    final self = userId == _VisualRepository.owner;
    return CommunityProfileOverview(
      userId: userId,
      displayName: self
          ? (arabic ? 'ملفي التجريبي' : 'My sample profile')
          : name,
      isSelf: self,
      relationship: self
          ? CommunityRelationshipStatus.self
          : CommunityRelationshipStatus.none,
      allowFriendRequests: true,
      allowFollows: true,
      showFollowers: true,
      showFollowing: true,
      showFriends: true,
      showPosts: true,
      showMembershipTier: false,
      handle: self ? 'sample_owner' : 'sample_member',
      bio: arabic
          ? 'لحظات موثوقة ومجتمع داعم.'
          : 'Trusted moments and a supportive community.',
      followerCount: self ? 128 : 84,
      followingCount: 36,
      friendCount: 18,
      postCount: 12,
      communityXp: 900,
      communityLevel: 4,
      communityLevelCopyKey: 'community_level_4',
      currentLevelMinXp: 700,
      nextCommunityLevel: 5,
      nextLevelMinXp: 1500,
      viewerFollows: !self,
      followsViewer: !self,
      goldBalance: self ? 644 : null,
    );
  }

  @override
  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async => CommunityFeedBatch(
    posts: [
      CommunityPost(
        id: profilePost,
        authorId: userId,
        authorName: userId == _VisualRepository.owner
            ? (arabic ? 'ملفي التجريبي' : 'My sample profile')
            : name,
        authorHandle: userId == _VisualRepository.owner
            ? 'sample_owner'
            : 'sample_member',
        body: arabic
            ? 'لحظة صغيرة تستحق المشاركة مع المجتمع.'
            : 'A small moment worth sharing with the community.',
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
    userId: userId,
    contributor: true,
    approvedPosts: 12,
    followers: userId == _VisualRepository.owner ? 128 : 84,
    likesReceived: 231,
    commentsReceived: 64,
    qualifiedReferrals: 3,
    communityXp: 900,
    communityLevel: 4,
    currentLevelMinXp: 700,
    nextCommunityLevel: 5,
    nextLevelMinXp: 1500,
    earnedBadgeCount: 4,
    totalBadgeCount: 7,
    badges: const [
      CommunityCreatorBadge(badgeKey: 'profile_complete', earned: true),
      CommunityCreatorBadge(badgeKey: 'first_moment', earned: true),
      CommunityCreatorBadge(badgeKey: 'contributor', earned: true),
      CommunityCreatorBadge(badgeKey: 'conversation_starter', earned: true),
      CommunityCreatorBadge(badgeKey: 'appreciated', earned: false),
      CommunityCreatorBadge(badgeKey: 'connector', earned: false),
      CommunityCreatorBadge(badgeKey: 'referral_builder', earned: false),
    ],
    certificationStatus: CommunityCreatorCertificationStatus.approved,
  );

  @override
  Future<List<CommunityProfileReview>> loadCommunityProfileReviews({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async => [
    CommunityProfileReview(
      reviewId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      productKind: 'food',
      canonicalName: arabic ? 'وجبة مجتمع موثوقة' : 'Verified community meal',
      brand: 'BIL',
      reviewNote: arabic ? 'مراجعة عامة معتمدة.' : 'An approved public review.',
      createdAt: DateTime.utc(2026, 10, 2),
    ),
  ];

  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async => [
    CommunityDraftSummary(
      draftId: draftId,
      title: arabic ? 'مسودة إنجاز' : 'Progress draft',
      body: arabic
          ? 'سأكمل هذه المشاركة لاحقًا.'
          : 'I will finish this community post later.',
      updatedAt: DateTime.utc(2026, 10, 3, 11),
      mediaCount: 2,
    ),
  ];

  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> postIds,
  ) async => {for (final id in postIds) id: 292};

  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> postIds) async => [
    for (final id in postIds)
      CommunityPostReferenceMetadata(
        postId: id,
        title: arabic ? 'لحظة مجتمع' : 'Community moment',
        hashtags: const ['progress', 'community'],
        topics: const [
          CommunityPostTopicReference(
            slug: 'success-stories',
            titleCopyKey: 'community_topic_success_stories',
            postCount: 42,
          ),
        ],
        collaborators: [
          CommunityPostCollaborator(
            userId: _VisualRepository.peer,
            displayName: name,
            handle: 'sample_member',
            status: CommunityCollaborationStatus.accepted,
          ),
        ],
      ),
  ];

  @override
  Future<String?> loadCommunityProfileCoverUrl(String userId) async => null;

  @override
  Future<CommunityGoldBalance> loadGoldBalance() async => CommunityGoldBalance(
    balance: 644,
    updatedAt: DateTime.utc(2026, 10, 3, 12),
  );

  @override
  Future<List<CommunityQuest>> loadCommunityQuests() async => [
    CommunityQuest(
      questKey: 'invite_friend',
      cadence: CommunityQuestCadence.oneTime,
      titleCopyKey: 'quest_invite_friend_title',
      subtitleCopyKey: 'quest_invite_friend_subtitle',
      actionKind: 'invite_friend',
      targetCount: 1,
      claimMode: CommunityQuestClaimMode.manual,
      goldReward: 100,
      xpReward: 100,
      periodKey: 'lifetime',
      progress: 1,
      state: CommunityQuestState.readyToClaim,
    ),
    CommunityQuest(
      questKey: 'valuable_post',
      cadence: CommunityQuestCadence.daily,
      titleCopyKey: 'quest_valuable_post_title',
      subtitleCopyKey: 'quest_valuable_post_subtitle',
      actionKind: 'valuable_post',
      targetCount: 1,
      claimMode: CommunityQuestClaimMode.manual,
      goldReward: 50,
      xpReward: 50,
      periodKey: '2026-10-03',
      progress: 1,
      state: CommunityQuestState.claimed,
      completedAt: DateTime.utc(2026, 10, 3, 9),
      claimedAt: DateTime.utc(2026, 10, 3, 9, 5),
    ),
    CommunityQuest(
      questKey: 'complete_profile',
      cadence: CommunityQuestCadence.oneTime,
      titleCopyKey: 'quest_complete_profile_title',
      subtitleCopyKey: 'quest_complete_profile_subtitle',
      actionKind: 'complete_profile',
      targetCount: 1,
      claimMode: CommunityQuestClaimMode.manual,
      goldReward: 25,
      xpReward: 25,
      periodKey: 'lifetime',
      progress: 1,
      state: CommunityQuestState.claimed,
      completedAt: DateTime.utc(2026, 10, 1),
      claimedAt: DateTime.utc(2026, 10, 1, 0, 5),
    ),
  ];

  @override
  Future<List<CommunityGoldLedgerEntry>> loadGoldHistory({
    DateTime? beforeCreatedAt,
    int? beforeId,
    int limit = 30,
  }) async => [
    CommunityGoldLedgerEntry(
      id: 3,
      delta: 50,
      balanceAfter: 644,
      sourceKind: 'quest_reward',
      copyKey: 'quest_valuable_post_reward',
      createdAt: DateTime.utc(2026, 10, 3, 9, 5),
    ),
    CommunityGoldLedgerEntry(
      id: 2,
      delta: 25,
      balanceAfter: 594,
      sourceKind: 'quest_reward',
      copyKey: 'quest_complete_profile_reward',
      createdAt: DateTime.utc(2026, 10, 1, 0, 5),
    ),
  ];
}

void main() {
  setUpAll(() async {
    await loadVisualEvidenceFont();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final arabic in [false, true]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'production Community surfaces ${arabic ? 'ar' : 'en'} ${dark ? 'dark' : 'light'} text $scale',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(414, 896);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final repository = _VisualRepository(arabic);
            final feedRepository = _FeedReferenceVisualRepository(arabic);
            final referenceRepository = _ReferenceVisualRepository(arabic);
            final controller = CommunityAttentionController(
              () async => const CommunityAttention(
                unreadMessages: 3,
                incomingRequests: 1,
                unreadBySender: {_VisualRepository.peer: 3},
              ),
            );
            controller.setOwner('fixture');
            await controller.refresh();
            final key = GlobalKey();
            final locale = Locale(arabic ? 'ar' : 'en');
            final theme = dark
                ? BilFlagshipTheme.dark(isArabic: arabic)
                : BilFlagshipTheme.light(isArabic: arabic);
            final scenes = <String, Widget>{
              'welcome': const Scaffold(body: CommunityWelcome()),
              'feed': CommunityHubPage(repository: feedRepository),
              'profile': CommunityProfilePage(repository: repository),
              'member_profile': CommunityMemberProfilePage(
                userId: _VisualRepository.peer,
                repository: referenceRepository,
              ),
              'creator_profile': CommunityMemberProfilePage(
                userId: _VisualRepository.owner,
                repository: referenceRepository,
              ),
              'rewards': CommunityRewardsPage(repository: referenceRepository),
              'my_code': CommunityBilCodePage(repository: repository),
              'my_posts': CommunityMyPostsPage(
                repository: repository,
                showProfileHeader: true,
              ),
              'saved': CommunitySavedPostsPage(repository: repository),
              'updates': CommunityNotificationsPage(repository: repository),
              'safety': CommunitySafetyPage(repository: repository),
              'find_people': CommunityPeoplePage(repository: repository),
              'messages': CommunityMessagesPage(repository: repository),
              'friends': CommunityConnectionsPage(repository: repository),
              'chat': CommunityChatPage(
                userId: _VisualRepository.peer,
                displayName: repository.name,
                repository: repository,
              ),
            };
            for (final scene in scenes.entries) {
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    verifiedSubscriptionStateProvider.overrideWithValue(
                      AsyncData(FreePlan.createState()),
                    ),
                  ],
                  child: MaterialApp(
                    theme: visualEvidenceTheme(
                      theme.copyWith(
                        textTheme: theme.textTheme.apply(
                          fontFamilyFallback: const [
                            'RobotoEvidence',
                            'NotoArabicEvidence',
                          ],
                        ),
                      ),
                      fontFamily: arabic
                          ? 'NotoArabicEvidence'
                          : 'RobotoEvidence',
                    ),
                    locale: locale,
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: true,
                      ),
                      child: CommunityAttentionScope(
                        controller: controller,
                        child: RepaintBoundary(key: key, child: child!),
                      ),
                    ),
                    home: CommunitySurface(child: scene.value),
                  ),
                ),
              );
              await tester.pump();
              if (scene.key == 'feed') {
                await tester.pump(const Duration(milliseconds: 2200));
              }
              await tester.pumpAndSettle();
              await settleVisualAssetImages(tester);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: scene.key);
              await _capture(
                tester,
                key,
                '${scene.key}_${locale.languageCode}_${dark ? 'dark' : 'light'}_${scale.toInt()}',
              );
              if (scene.key == 'feed') {
                await tester.tap(find.byKey(const Key('community-settings')));
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const Key('community-nav-messages')),
                  findsOneWidget,
                );
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'navigation sheet',
                );
                await _capture(
                  tester,
                  key,
                  'actions_${locale.languageCode}_${dark ? 'dark' : 'light'}_${scale.toInt()}',
                );
                tester
                    .state<NavigatorState>(find.byType(Navigator).first)
                    .pop();
                await tester.pumpAndSettle();
                final comments = find.byKey(
                  const Key(
                    'community-post-comments-66666666-6666-4666-8666-666666666666',
                  ),
                );
                await tester.ensureVisible(comments);
                await tester.pumpAndSettle();
                final commentsRect = tester.getRect(comments);
                expect(
                  commentsRect.bottom,
                  lessThanOrEqualTo(tester.view.physicalSize.height),
                  reason: 'comment action must be on-screen before tap',
                );
                await tester.tap(comments);
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'post details/comments',
                );
                await _capture(
                  tester,
                  key,
                  'comments_${locale.languageCode}_${dark ? 'dark' : 'light'}_${scale.toInt()}',
                );
                tester
                    .state<NavigatorState>(find.byType(Navigator).first)
                    .pop();
                await tester.pumpAndSettle();
                await tester.tap(
                  find.byKey(const Key('community-create-post')),
                );
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const Key('community-post-editor-page')),
                  findsOneWidget,
                );
                expect(tester.takeException(), isNull, reason: 'create post');
                await _capture(
                  tester,
                  key,
                  'composer_${locale.languageCode}_${dark ? 'dark' : 'light'}_${scale.toInt()}',
                );
              }
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            }
            controller.dispose();
          },
        );
      }
    }
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['BIL_COMMUNITY_CAPTURE_DIR'];
  if (directory == null || directory.isEmpty) return;
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 1.5);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
