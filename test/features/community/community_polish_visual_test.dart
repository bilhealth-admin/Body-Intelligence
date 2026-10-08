import 'dart:io';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/community/channels/domain/community_channel_models.dart';
import 'package:body_intelligence_log/features/community/channels/domain/community_channels_repository.dart';
import 'package:body_intelligence_log/features/community/channels/presentation/community_channels_page.dart';
import 'package:body_intelligence_log/features/community/circle_management/circle_management_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/presentation/community_post_moderation_page.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
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
  Future<Map<String, String>> loadVisibleMembershipTiers(
    List<String> userIds,
  ) async => const <String, String>{};
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
  Future<List<CommunityNotification>> loadCommunityNotifications({
    DateTime? before,
    String? beforeId,
    List<CommunityNotificationKind>? kinds,
    int limit = 30,
  }) async => [
    CommunityNotification(
      id: '99999999-9999-4999-8999-999999999999',
      kind: CommunityNotificationKind.friendAccepted,
      actorId: peer,
      actorDisplayName: name,
      createdAt: DateTime.utc(2026, 10, 3, 8),
      entityKind: 'friendship',
      entityId: '33333333-3333-4333-8333-333333333333',
      friendshipId: '33333333-3333-4333-8333-333333333333',
      copyKey: 'friend_accepted_v1',
      deepLinkPath: '/community/connections',
    ),
    CommunityNotification(
      id: '55555555-5555-4555-8555-555555555555',
      kind: CommunityNotificationKind.rewardEarned,
      actorId: owner,
      createdAt: DateTime.utc(2026, 10, 3, 7, 58),
      entityKind: 'post',
      entityId: '66666666-6666-4666-8666-666666666666',
      copyKey: 'post_approved_ai_tokens_v1',
      deepLinkPath: '/community/post/66666666-6666-4666-8666-666666666666',
      metadata: const {
        'receipt_kind': 'post_moderation',
        'post_id': '66666666-6666-4666-8666-666666666666',
        'decision': 'approved',
        'ai_tokens_granted': 5,
        'reward_reason': 'granted',
      },
    ),
    CommunityNotification(
      id: '44444444-4444-4444-8444-444444444441',
      kind: CommunityNotificationKind.postLike,
      actorId: peer,
      actorDisplayName: name,
      createdAt: DateTime.utc(2026, 10, 3, 7, 45),
      entityKind: 'post',
      entityId: '66666666-6666-4666-8666-666666666666',
      copyKey: 'post_like_v1',
      deepLinkPath: '/community',
    ),
    CommunityNotification(
      id: '44444444-4444-4444-8444-444444444442',
      kind: CommunityNotificationKind.comment,
      actorId: peer,
      actorDisplayName: name,
      createdAt: DateTime.utc(2026, 10, 3, 7, 30),
      entityKind: 'post',
      entityId: '66666666-6666-4666-8666-666666666666',
      copyKey: 'comment_v1',
      deepLinkPath: '/community',
    ),
    CommunityNotification(
      id: '44444444-4444-4444-8444-444444444443',
      kind: CommunityNotificationKind.mention,
      actorId: peer,
      actorDisplayName: name,
      createdAt: DateTime.utc(2026, 10, 2, 9),
      entityKind: 'post',
      entityId: '66666666-6666-4666-8666-666666666666',
      copyKey: 'mention_v1',
      deepLinkPath: '/community',
      seenAt: DateTime.utc(2026, 10, 2, 11),
    ),
  ];
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
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async {
    final posts = await super.loadFeed(limit: limit);
    if (posts.isEmpty) return posts;
    // Four genuinely bundled BIL image assets, not fabricated network URLs.
    // This is a view-only QA gallery, never user content or a database write.
    return [
      posts.first.withMedia(const [
        CommunityPostMedia(
          position: 0,
          objectPath: 'fixture/meal-1.jpg',
          mimeType: 'image/jpeg',
          bytes: 1,
          width: 400,
          height: 400,
          url: 'asset://assets/images/professional/recipes/bean_corn_salad.jpg',
        ),
        CommunityPostMedia(
          position: 1,
          objectPath: 'fixture/meal-2.jpg',
          mimeType: 'image/jpeg',
          bytes: 1,
          width: 400,
          height: 400,
          url:
              'asset://assets/images/professional/recipes/chicken_shawarma_bowl.jpg',
        ),
        CommunityPostMedia(
          position: 2,
          objectPath: 'fixture/workout-1.jpg',
          mimeType: 'image/jpeg',
          bytes: 1,
          width: 400,
          height: 400,
          url: 'asset://assets/images/professional/workouts/brisk_walk.jpg',
        ),
        CommunityPostMedia(
          position: 3,
          objectPath: 'fixture/workout-2.jpg',
          mimeType: 'image/jpeg',
          bytes: 1,
          width: 400,
          height: 400,
          url:
              'asset://assets/images/professional/workouts/full_body_strength.jpg',
        ),
      ]),
      ...posts.skip(1),
    ];
  }

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
    const CommunityTopic(
      slug: 'fitness',
      titleCopyKey: 'community_topic_fitness',
      descriptionCopyKey: 'community_topic_fitness_body',
      iconKey: 'fitness',
      featured: true,
      followerCount: 182,
      postCount: 44,
      following: false,
    ),
    const CommunityTopic(
      slug: 'motivation-support',
      titleCopyKey: 'community_topic_motivation_support',
      descriptionCopyKey: 'community_topic_motivation_support_body',
      iconKey: 'heart',
      featured: true,
      followerCount: 92,
      postCount: 18,
      following: false,
    ),
    const CommunityTopic(
      slug: 'wellness',
      titleCopyKey: 'community_topic_wellness',
      descriptionCopyKey: 'community_topic_wellness_body',
      iconKey: 'wellness',
      featured: true,
      followerCount: 156,
      postCount: 33,
      following: false,
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

/// Synthetic readback states: no account, production write or network request.
/// Capture success proves native rendering, not approved-reference pixel parity.
final class _ExtendedVisualRepository extends _ReferenceVisualRepository {
  _ExtendedVisualRepository(super.arabic);

  static const pendingPostId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  static List<CommunityPostImagePreview?> get loadedDraftPreviews =>
      _draftPreviews;
  static List<CommunityPostImagePreview?> _draftPreviews = const [];
  static List<CommunityDraftMediaMetadata> _draftMedia = const [];
  static List<CommunityPostImageDraft> _composerImages = const [];

  static List<CommunityPostImageDraft> get composerImages => _composerImages;

  static Future<void> preloadPhotoFixtures() async {
    if (_draftPreviews.length == 4) return;
    final previews = <CommunityPostImagePreview?>[];
    final metadata = <CommunityDraftMediaMetadata>[];
    final originals = <CommunityPostImageDraft>[];
    for (final path in const [
      'assets/images/professional/recipes/bean_corn_salad.jpg',
      'assets/images/professional/recipes/chicken_shawarma_bowl.jpg',
      'assets/images/professional/workouts/brisk_walk.jpg',
      'assets/images/professional/workouts/full_body_strength.jpg',
    ]) {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw StateError('Bundled BIL visual fixture could not be decoded');
      }
      final position = metadata.length;
      // Exercise the same validated draft type used by the real post editor.
      originals.add(await validateCommunityPostImageAsync(bytes));
      previews.add(
        await createCommunityPostImagePreviewAsync(
          bytes,
          expectedMimeType: 'image/jpeg',
          expectedByteLength: bytes.length,
          expectedWidth: decoded.width,
          expectedHeight: decoded.height,
        ),
      );
      metadata.add(
        CommunityDraftMediaMetadata(
          position: position,
          objectPath: 'fixture/photo-$position.jpg',
          mimeType: 'image/jpeg',
          bytes: bytes.length,
          width: decoded.width,
          height: decoded.height,
        ),
      );
    }
    _draftPreviews = List<CommunityPostImagePreview?>.unmodifiable(previews);
    _draftMedia = List<CommunityDraftMediaMetadata>.unmodifiable(metadata);
    _composerImages = List<CommunityPostImageDraft>.unmodifiable(originals);
  }

  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async {
    final rows = await super.listMyCommunityDrafts(
      before: before,
      beforeId: beforeId,
      limit: limit,
    );
    return [
      for (final row in rows)
        CommunityDraftSummary(
          draftId: row.draftId,
          title: row.title,
          body: row.body,
          updatedAt: row.updatedAt,
          mediaCount: 4,
        ),
    ];
  }

  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => [
    ManagedCommunityCircle(
      circle: const CommunityCircle(
        slug: '10k-steps',
        titleCopyKey: 'community_circle_10k_steps',
        descriptionCopyKey: 'community_circle_10k_steps_body',
        rulesCopyKey: 'community_circle_standard_rules',
        access: CommunityCircleAccess.public,
        joinPolicy: CommunityCircleJoinPolicy.open,
        featured: true,
        memberCount: 830,
        postCount: 123,
        membershipStatus: CommunityCircleMembershipStatus.active,
        membershipRole: CommunityCircleMembershipRole.member,
      ),
      displayName: arabic ? '١٠ آلاف خطوة' : '10K Steps',
      description: arabic
          ? 'نشارك خطواتنا اليومية ونشجع بعضنا.'
          : 'Share daily steps and encourage each other.',
    ),
    ManagedCommunityCircle(
      circle: const CommunityCircle(
        slug: 'healthy-eating',
        titleCopyKey: 'community_circle_healthy_eating',
        descriptionCopyKey: 'community_circle_healthy_eating_body',
        rulesCopyKey: 'community_circle_standard_rules',
        access: CommunityCircleAccess.public,
        joinPolicy: CommunityCircleJoinPolicy.request,
        featured: true,
        memberCount: 468,
        postCount: 69,
      ),
      displayName: arabic ? 'إعداد وجبات صحية' : 'Meal Prep & Nutrition',
      description: arabic
          ? 'شارك أفكار الوجبات والعادات المفيدة.'
          : 'Share practical meals and sustainable habits.',
    ),
    // Visual-only rows are never inserted into the Community database.
    // The native page must support the complete approved six-row density.
    ManagedCommunityCircle(
      circle: const CommunityCircle(
        slug: 'intermittent-fasting',
        titleCopyKey: 'community_circle_native_title',
        descriptionCopyKey: 'community_circle_native_description',
        rulesCopyKey: 'community_circle_standard_rules',
        access: CommunityCircleAccess.public,
        joinPolicy: CommunityCircleJoinPolicy.open,
        memberCount: 1800,
        postCount: 67,
      ),
      displayName: arabic ? 'الصيام المتقطع' : 'Intermittent Fasting',
    ),
    ManagedCommunityCircle(
      circle: const CommunityCircle(
        slug: 'muscle-building',
        titleCopyKey: 'community_circle_native_title',
        descriptionCopyKey: 'community_circle_native_description',
        rulesCopyKey: 'community_circle_standard_rules',
        access: CommunityCircleAccess.public,
        joinPolicy: CommunityCircleJoinPolicy.open,
        memberCount: 2600,
        postCount: 108,
      ),
      displayName: arabic ? 'بناء العضلات' : 'Muscle Building',
    ),
    ManagedCommunityCircle(
      circle: const CommunityCircle(
        slug: 'sleep-better',
        titleCopyKey: 'community_circle_native_title',
        descriptionCopyKey: 'community_circle_native_description',
        rulesCopyKey: 'community_circle_standard_rules',
        access: CommunityCircleAccess.public,
        joinPolicy: CommunityCircleJoinPolicy.open,
        memberCount: 1100,
        postCount: 40,
      ),
      displayName: arabic ? 'نوم أفضل' : 'Sleep Better',
    ),
    ManagedCommunityCircle(
      circle: const CommunityCircle(
        slug: 'mental-health-mindset',
        titleCopyKey: 'community_circle_native_title',
        descriptionCopyKey: 'community_circle_native_description',
        rulesCopyKey: 'community_circle_standard_rules',
        access: CommunityCircleAccess.public,
        joinPolicy: CommunityCircleJoinPolicy.open,
        memberCount: 1900,
        postCount: 55,
      ),
      displayName: arabic
          ? 'الصحة النفسية والتحفيز'
          : 'Mental Health & Mindset',
    ),
  ];

  @override
  Future<
    ({CommunityPersistentDraft draft, List<CommunityPostImagePreview?> images})
  >
  loadMyCommunityDraftMosaicPreview(String draftId, {int maxImages = 4}) async {
    // Preview bytes are bounded by the same decoder as production; originals
    // remain local BIL assets. This is synthetic, not user-owned draft data.
    if (_draftPreviews.length != 4 || _draftMedia.length != 4) {
      throw StateError('Native draft photo fixtures were not preloaded');
    }
    return (
      draft: CommunityPersistentDraft(
        draftId: draftId,
        title: arabic ? 'مسودة إنجاز' : 'Progress draft',
        body: arabic
            ? 'سأكمل هذه المشاركة لاحقًا.'
            : 'I will finish this community post later.',
        topicSlugs: const ['nutrition'],
        mentions: const [],
        collaborators: const [],
        hashtags: const ['progress'],
        pollOptions: const [],
        pollAllowMultiple: false,
        createdAt: DateTime.utc(2026, 10, 3, 10),
        updatedAt: DateTime.utc(2026, 10, 3, 11),
        media: _draftMedia,
      ),
      images: _draftPreviews,
    );
  }

  @override
  Future<bool> isCommunityModerator() async => true;

  @override
  Future<T> runForCommunityOwner<T>(
    Future<T> Function() action, {
    required String ownerId,
    required bool Function() isCurrentOwner,
  }) async {
    if (ownerId != _VisualRepository.owner || !isCurrentOwner()) {
      throw const AuthException('Synthetic Community owner changed');
    }
    return action();
  }

  @override
  Future<List<CommunityPost>> loadPendingPostsForModeration({
    int limit = 100,
  }) async => [
    CommunityPost(
      id: pendingPostId,
      authorId: _VisualRepository.peer,
      authorName: name,
      body: arabic
          ? 'رحلة جديدة نحو عادات أفضل. شاركوني تجاربكم!'
          : 'A new step toward better habits. Share your experience!',
      createdAt: DateTime.utc(2026, 10, 3, 9),
      moderationStatus: CommunityPostModerationStatus.pending,
      media: const [
        CommunityPostMedia(
          position: 0,
          objectPath: 'fixture/moderation-1.jpg',
          mimeType: 'image/jpeg',
          bytes: 1,
          width: 400,
          height: 400,
          url: 'asset://assets/images/professional/recipes/bean_corn_salad.jpg',
        ),
        CommunityPostMedia(
          position: 1,
          objectPath: 'fixture/moderation-2.jpg',
          mimeType: 'image/jpeg',
          bytes: 1,
          width: 400,
          height: 400,
          url:
              'asset://assets/images/professional/workouts/full_body_strength.jpg',
        ),
      ],
    ),
    CommunityPost(
      id: 'abababab-abab-4bab-8bab-abababababab',
      authorId: _VisualRepository.peer,
      authorName: arabic ? 'عضو المجتمع' : 'Community member',
      body: arabic
          ? 'تحدّي لياقة لمدة ثلاثين يومًا.'
          : 'My 30-day fitness journey.',
      createdAt: DateTime.utc(2026, 10, 3, 8, 30),
      moderationStatus: CommunityPostModerationStatus.pending,
      media: const [
        CommunityPostMedia(
          position: 0,
          objectPath: 'fixture/moderation-3.jpg',
          mimeType: 'image/jpeg',
          bytes: 1,
          width: 400,
          height: 400,
          url: 'asset://assets/images/professional/workouts/brisk_walk.jpg',
        ),
      ],
    ),
    CommunityPost(
      id: 'cdcdcdcd-cdcd-4dcd-8dcd-cdcdcdcdcdcd',
      authorId: _VisualRepository.peer,
      authorName: arabic ? 'عضو المجتمع' : 'Community member',
      body: arabic
          ? 'أفكار وجبات صحية وسهلة لأيام العمل.'
          : 'Healthy snack and meal ideas for busy days.',
      createdAt: DateTime.utc(2026, 10, 3, 8, 10),
      moderationStatus: CommunityPostModerationStatus.pending,
      media: const [
        CommunityPostMedia(
          position: 0,
          objectPath: 'fixture/moderation-4.jpg',
          mimeType: 'image/jpeg',
          bytes: 1,
          width: 400,
          height: 400,
          url:
              'asset://assets/images/professional/recipes/chicken_shawarma_bowl.jpg',
        ),
      ],
    ),
  ];

  @override
  Future<List<CommunityPost>> loadHiddenPostsForModeration({
    int limit = 100,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> loadOpenModerationReports() async =>
      const [];

  @override
  Future<List<CommunityPost>> hydrateModerationReviewContents(
    List<CommunityPost> posts,
  ) async => posts;
}

/// The real native picker contract, injected with bundled synthetic QA
/// originals. No permissions, photo library, Cloud Storage, or user data.
final class _NativeVisualImagePicker
    implements CommunityPostImagePickerContract {
  _NativeVisualImagePicker(this.images);

  final List<CommunityPostImageDraft> images;
  int _next = 0;

  @override
  Future<CommunityPostImageDraft?> pick() async {
    if (_next >= images.length) return null;
    return images[_next++];
  }
}

final class _VisualChannelsRepository implements CommunityChannelsRepository {
  _VisualChannelsRepository(this.arabic);

  static const firstChannel = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  final bool arabic;

  @override
  String? get currentOwnerId => _VisualRepository.owner;

  @override
  Stream<String?> get ownerChanges => const Stream<String?>.empty();

  @override
  Future<CommunityChannelCapabilities> loadCapabilities(
    ChannelRequestScope scope,
  ) async {
    scope.check();
    return const CommunityChannelCapabilities();
  }

  @override
  Future<CommunityChannelDirectory> loadDirectory(
    ChannelRequestScope scope, {
    String? afterId,
    int limit = 50,
  }) async {
    scope.check();
    return CommunityChannelDirectory(
      channels: [
        CommunityChannel(
          id: firstChannel,
          slug: 'general',
          title: arabic ? 'العام' : 'General',
          description: arabic
              ? 'حوار المجتمع ومشاركة عادات يومية مفيدة.'
              : 'Meet the community and share daily progress.',
          visibility: 'public',
          enabled: true,
          membership: 'member',
          canRead: true,
          canSend: true,
          unreadCount: 3,
          latestSequence: 2,
        ),
        CommunityChannel(
          id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          slug: 'nutrition',
          title: arabic ? 'التغذية' : 'Nutrition',
          description: arabic
              ? 'أفكار الوجبات اليومية ووصفات متنوعة.'
              : 'Meal ideas, recipes and encouragement.',
          visibility: 'public',
          enabled: true,
          membership: 'member',
          canRead: true,
          canSend: true,
          unreadCount: 8,
          latestSequence: 11,
        ),
        CommunityChannel(
          id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          slug: 'workouts',
          title: arabic ? 'التمارين' : 'Workouts',
          description: arabic
              ? 'خطط تدريب وتقدّم مشترك.'
              : 'Training plans and shared progress.',
          visibility: 'public',
          enabled: true,
          membership: 'member',
          canRead: true,
          canSend: true,
          unreadCount: 0,
          latestSequence: 9,
        ),
        CommunityChannel(
          id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
          slug: 'mindset',
          title: arabic ? 'التحفيز' : 'Mindset',
          description: arabic
              ? 'التشجيع والعادات اليومية.'
              : 'Motivation, habits and growth.',
          visibility: 'public',
          enabled: true,
          membership: 'member',
          canRead: true,
          canSend: true,
          unreadCount: 2,
          latestSequence: 7,
        ),
        CommunityChannel(
          id: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
          slug: 'sleep-recovery',
          title: arabic ? 'النوم والتعافي' : 'Sleep & Recovery',
          description: arabic
              ? 'نوم أفضل وعادات مريحة.'
              : 'Better rest and recovery habits.',
          visibility: 'public',
          enabled: true,
          membership: 'member',
          canRead: true,
          canSend: false,
          unreadCount: 0,
          latestSequence: 6,
        ),
        CommunityChannel(
          id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaab',
          slug: 'success-stories',
          title: arabic ? 'قصص النجاح' : 'Success Stories',
          description: arabic
              ? 'تجارب التقدم ودعم المجتمع.'
              : 'Real progress and community support.',
          visibility: 'public',
          enabled: true,
          membership: 'member',
          canRead: true,
          canSend: true,
          unreadCount: 1,
          latestSequence: 5,
        ),
      ],
      serverTime: DateTime.utc(2026, 10, 3),
    );
  }

  @override
  Future<CommunityChannelMessagePage> loadMessages(
    ChannelRequestScope scope,
    String channelId, {
    int? beforeSequence,
    int? afterSequence,
    int limit = 50,
  }) async {
    scope.check();
    return CommunityChannelMessagePage(
      messages: afterSequence != null && afterSequence >= 2
          ? const <CommunityChannelMessage>[]
          : [
              CommunityChannelMessage(
                id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
                channelId: channelId,
                sequence: 1,
                authorId: _VisualRepository.peer,
                authorDisplayName: arabic ? 'عضو المجتمع' : 'Community member',
                text: arabic
                    ? 'صباح الخير! كيف بدأ يومكم؟'
                    : 'Good morning! How did your day start?',
                clientMessageId: null,
                createdAt: DateTime.utc(2026, 10, 3, 8),
                isRead: true,
              ),
              CommunityChannelMessage(
                id: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
                channelId: channelId,
                sequence: 2,
                authorId: _VisualRepository.owner,
                authorDisplayName: arabic ? 'أنا' : 'Me',
                text: arabic
                    ? 'بدأت بنزهة قصيرة، وسأشارك تقدمي.'
                    : 'I started with a short walk and will share my progress.',
                clientMessageId: null,
                createdAt: DateTime.utc(2026, 10, 3, 8, 2),
                isRead: true,
              ),
            ],
      hasMore: false,
      serverTime: DateTime.utc(2026, 10, 3, 8, 10),
    );
  }

  @override
  Future<CommunityChannelMessage> send(
    ChannelRequestScope scope,
    CommunityChannelSendAttempt attempt,
  ) async => throw StateError('Synthetic capture is read-only');

  @override
  Future<CommunityChannelReadback> acknowledgeVisible(
    ChannelRequestScope scope,
    String channelId,
    List<String> messageIds,
  ) async {
    scope.check();
    return CommunityChannelReadback(
      confirmedIds: messageIds.toSet(),
      unreadCount: 0,
      serverTime: DateTime.utc(2026, 10, 3, 8, 10),
    );
  }

  @override
  Future<CommunityChannelPresence> loadPresence(
    ChannelRequestScope scope,
    String channelId, {
    required bool heartbeat,
    required bool Function() isForeground,
  }) async {
    scope.check();
    final now = DateTime.now().toUtc();
    return CommunityChannelPresence(
      onlineCount: 12,
      serverTime: now,
      validUntil: now.add(const Duration(seconds: 90)),
    );
  }

  @override
  Stream<CommunityChannelChange> watchChanges(
    ChannelRequestScope scope,
    String? channelId,
  ) => const Stream<CommunityChannelChange>.empty();
}

void main() {
  setUpAll(() async {
    await loadVisualEvidenceFont();
    await _ExtendedVisualRepository.preloadPhotoFixtures();
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
            final extendedRepository = _ExtendedVisualRepository(arabic);
            final channelsRepository = _VisualChannelsRepository(arabic);
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
              'feed': CommunityHubPage(
                repository: feedRepository,
                postImagePicker: _NativeVisualImagePicker(
                  _ExtendedVisualRepository.composerImages,
                ),
              ),
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
              'drafts': CommunityDraftsPage(repository: extendedRepository),
              'circles': CommunityCirclesPage(repository: extendedRepository),
              'moderation': CommunityPostModerationPage(
                repository: extendedRepository,
              ),
              'channels': CommunityChannelsPage(repository: channelsRepository),
              'channel_chat': CommunityChannelMessagesPage(
                repository: channelsRepository,
                channelId: _VisualChannelsRepository.firstChannel,
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
              if (scene.key == 'drafts') {
                // Decode the actual BIL thumbnails before taking a GPU
                // snapshot. Image.memory's asynchronous codec may otherwise
                // leave white pixels in an otherwise passing host capture.
                final surface = find
                    .byKey(const Key('community-drafts-page'))
                    .evaluate()
                    .first;
                await tester.runAsync(() async {
                  for (final preview
                      in _ExtendedVisualRepository.loadedDraftPreviews) {
                    if (preview == null) continue;
                    await precacheImage(MemoryImage(preview.bytes), surface);
                  }
                });
                await tester.pumpAndSettle();
              }
              expect(tester.takeException(), isNull, reason: scene.key);
              if (scene.key == 'drafts') {
                expect(
                  find.byKey(const Key('community-drafts-page')),
                  findsOneWidget,
                );
                expect(
                  find.byKey(
                    const Key(
                      'community-draft-photo-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa-0',
                    ),
                  ),
                  findsOneWidget,
                );
              }
              if (scene.key == 'circles') {
                expect(
                  find.byKey(const Key('community-circles-list')),
                  findsOneWidget,
                );
              }
              if (scene.key == 'moderation') {
                expect(
                  find.byKey(
                    const Key(
                      'community-moderation-post-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    ),
                  ),
                  findsOneWidget,
                );
              }
              if (scene.key == 'channels') {
                expect(
                  find.byKey(const Key('bil07-directory')),
                  findsOneWidget,
                );
              }
              if (scene.key == 'channel_chat') {
                expect(
                  find.byKey(const Key('bil07-channels-page')),
                  findsOneWidget,
                );
              }
              if (scene.key == 'updates') {
                expect(
                  find.byKey(const Key('community-activity-filter-updates')),
                  findsOneWidget,
                  reason:
                      'Activity evidence must show loaded server-contract rows, not an error fallback',
                );
                expect(
                  find.widgetWithText(
                    ListTile,
                    arabic
                        ? '${repository.name} قبل طلب صداقتك'
                        : '${repository.name} accepted your friend request',
                  ),
                  findsOneWidget,
                  reason: 'Activity must render the loaded acceptance event',
                );
              }
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
                await tester.scrollUntilVisible(
                  comments.hitTestable(),
                  180,
                  scrollable: find
                      .descendant(
                        of: find.byKey(
                          const PageStorageKey('community-feed-scroll-explore'),
                        ),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                );
                await tester.pumpAndSettle();
                final commentsRect = tester.getRect(comments);
                expect(
                  commentsRect.bottom,
                  lessThanOrEqualTo(tester.view.physicalSize.height),
                  reason: 'comment action must be on-screen before tap',
                );
                expect(comments.hitTestable(), findsOneWidget);
                await tester.tap(comments);
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'post details/comments',
                );
                expect(
                  find.byKey(const Key('community-post-detail-list')),
                  findsOneWidget,
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
                final composer = find.byKey(const Key('community-create-post'));
                await tester.scrollUntilVisible(
                  composer,
                  -220,
                  scrollable: find
                      .descendant(
                        of: find.byKey(
                          const PageStorageKey('community-feed-scroll-explore'),
                        ),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                );
                await tester.pumpAndSettle();
                expect(composer.hitTestable(), findsOneWidget);
                await tester.tap(composer);
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const Key('community-post-editor-page')),
                  findsOneWidget,
                );
                expect(tester.takeException(), isNull, reason: 'create post');
                // MemoryImage is decoded asynchronously even with a local,
                // validated BIL picker. Precache the exact bytes before
                // capturing so synthetic white tiles cannot look like a
                // successful reference screenshot.
                final editorContext = tester.element(
                  find.byKey(const Key('community-post-editor-page')),
                );
                await tester.runAsync(() async {
                  for (final photo
                      in _ExtendedVisualRepository.composerImages.take(3)) {
                    await precacheImage(
                      MemoryImage(photo.bytes),
                      editorContext,
                    );
                  }
                });
                await tester.pumpAndSettle();
                // Populate the real editor's four slots through the injected
                // picker, preserving native validation and undo.
                for (var index = 0; index < 3; index++) {
                  final addPhoto = find.byKey(
                    const Key('community-post-add-photo'),
                  );
                  await tester.ensureVisible(addPhoto);
                  await tester.pumpAndSettle();
                  await tester.tap(addPhoto);
                  await tester.pumpAndSettle();
                  final photoTile = find.byKey(
                    Key('community-selected-photo-$index'),
                  );
                  expect(
                    photoTile,
                    findsOneWidget,
                    reason: 'approved 3-photo + add composition',
                  );
                  expect(
                    find.descendant(
                      of: photoTile,
                      matching: find.byWidgetPredicate(
                        (widget) => widget is RawImage && widget.image != null,
                      ),
                    ),
                    findsOneWidget,
                    reason: 'Actual decoded photograph, not a blank tile',
                  );
                }
                await settleVisualAssetImages(tester);
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'three native image-picker actions',
                );
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
