part of 'community_profile_drafts_reference_capture_test.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _post = '33333333-3333-4333-8333-333333333333';

class _ReferenceAuth {
  String owner = _owner;
  int unexpectedRequests = 0;
  final sessions = <String, String>{};
  late final client = SupabaseClient(
    'https://profile-drafts.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(
      MockClient((request) async {
        if (request.url.path != '/auth/v1/token') {
          unexpectedRequests++;
          throw StateError('Unexpected fixture request: ${request.url.path}');
        }
        final payload = base64Url
            .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
            .replaceAll('=', '');
        return http.Response(
          jsonEncode({
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': owner,
              'email': 'reference@example.invalid',
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-10-06T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    ),
  );
  Future<void> prepare() async {
    for (final value in [_other, _owner]) {
      owner = value;
      await client.auth.signInWithPassword(
        email: 'reference@example.invalid',
        password: 'synthetic',
      );
      sessions[value] = jsonEncode(client.auth.currentSession!.toJson());
    }
  }

  Future<void> roundTrip() async {
    final other = client.auth.recoverSession(sessions[_other]!);
    final original = client.auth.recoverSession(sessions[_owner]!);
    await Future.wait([other, original]);
  }
}

class _ReferenceRepository extends CommunityRepository {
  _ReferenceRepository(
    super.client,
    this.photos,
    this.previews, {
    List<int>? avatarBytes,
  }) : avatarBytes = avatarBytes ?? photos[3].bytes;
  final List<int> avatarBytes;
  final List<CommunityPostImageDraft> photos;
  final List<CommunityPostImagePreview> previews;
  bool everyDraftHasFourPhotos = false;
  bool arabic = false;
  int totalDrafts = 2;
  int profileReads = 0;
  int codeReads = 0;
  int saves = 0;
  bool loseNextSaveReply = false;
  final saveInputs = <CommunityDraftSaveInput>[];
  final saveImages = <List<CommunityPostImageDraft>>[];
  int policies = 0;
  int activePreviews = 0;
  int peakPreviews = 0;
  bool failNextPage = false;
  bool failNextPreview = false;
  final badPhotos = <int>{};
  final opened = <String>[];
  final previewStarts = <({String owner, String id})>[];
  final listCalls =
      <({String owner, DateTime? before, String? beforeId, int limit})>[];
  Completer<List<CommunityDraftSummary>>? nextPage;
  Completer<void>? previewPause;
  final savedBodies = <String, String>{};
  final savedTitles = <String, String>{};
  final savedTimes = <String, DateTime>{};

  String id(int index) =>
      'aaaaaaaa-aaaa-4aaa-8aaa-${index.toString().padLeft(12, '0')}';
  int indexFor(String draftId) => int.parse(draftId.split('-').last);
  String title(int index) =>
      savedTitles[id(index)] ??
      (arabic
          ? (index == 0
                ? 'خطوات بسيطة ليوم أفضل'
                : 'أفكار تحضير الوجبات $index')
          : (index == 0
                ? 'Small habits for a better day'
                : 'Meal preparation ideas $index'));
  String body(int index) =>
      savedBodies[id(index)] ??
      (arabic
          ? 'وجبة متوازنة وحركة يومية ووقت للراحة. خطوات صغيرة تساعدنا على الاستمرار.'
          : 'Balanced food, a little movement, and time to rest. Small habits help us keep going.');
  CommunityPersistentDraft draft(int index) {
    final count = everyDraftHasFourPhotos || index == 0
        ? 4
        : index == 1
        ? 2
        : 0;
    return CommunityPersistentDraft.fromJson({
      'draft_id': id(index),
      'title': title(index),
      'body': body(index),
      'topic_slugs': ['nutrition'],
      'circle_slug': index == 0 ? 'healthy-eating' : null,
      'location_label': index == 0 ? (arabic ? 'ملبورن' : 'Melbourne') : null,
      'mentions': [],
      'collaborators': [],
      'hashtags': ['healthyhabits', 'nutrition'],
      'poll_question': index == 0
          ? (arabic ? 'ما العادة التي تساعدك؟' : 'Which habit helps you?')
          : null,
      'poll_options': index == 0
          ? (arabic
                ? ['غذاء متوازن', 'نوم جيد']
                : ['Balanced food', 'Good sleep'])
          : [],
      'poll_allow_multiple': false,
      'created_at': '2026-10-05T09:00:00Z',
      'updated_at':
          (savedTimes[id(index)] ??
                  DateTime.utc(
                    2026,
                    10,
                    6,
                    12,
                  ).subtract(Duration(minutes: index)))
              .toIso8601String(),
      'media': [
        for (var position = 0; position < count; position++)
          {
            'position': position,
            'object_path':
                '$currentUserId/${id(index)}/$position.${photos[position].extension}',
            'mime_type': photos[position].mimeType,
            'bytes': photos[position].byteLength,
            'width': photos[position].width,
            'height': photos[position].height,
          },
      ],
    });
  }

  List<CommunityDraftSummary> page({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) {
    final all = [
      for (var index = 0; index < totalDrafts; index++) draft(index),
    ];
    return [
      for (final value
          in all
              .where(
                (value) =>
                    before == null ||
                    value.updatedAt.isBefore(before) ||
                    (value.updatedAt == before &&
                        value.draftId.compareTo(beforeId!) < 0),
              )
              .take(limit))
        CommunityDraftSummary(
          draftId: value.draftId,
          title: value.title,
          body: value.body,
          updatedAt: value.updatedAt,
          mediaCount: value.media.length,
        ),
    ];
  }

  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async {
    listCalls.add((
      owner: currentUserId,
      before: before,
      beforeId: beforeId,
      limit: limit,
    ));
    if (before != null) {
      if (failNextPage) {
        failNextPage = false;
        throw StateError('Synthetic page failure');
      }
      final pending = nextPage;
      nextPage = null;
      if (pending != null) return pending.future;
    }
    return page(before: before, beforeId: beforeId, limit: limit);
  }

  @override
  Future<
    ({CommunityPersistentDraft draft, List<CommunityPostImagePreview?> images})
  >
  loadMyCommunityDraftMosaicPreview(String draftId, {int maxImages = 4}) async {
    previewStarts.add((owner: currentUserId, id: draftId));
    activePreviews++;
    if (activePreviews > peakPreviews) peakPreviews = activePreviews;
    try {
      await previewPause?.future;
      if (failNextPreview) {
        failNextPreview = false;
        throw StateError('Synthetic preview failure');
      }
      final value = draft(indexFor(draftId));
      return (
        draft: value,
        images: [
          for (
            var index = 0;
            index < value.media.length && index < maxImages;
            index++
          )
            badPhotos.contains(index) ? null : previews[index],
        ],
      );
    } finally {
      activePreviews--;
    }
  }

  @override
  Future<
    ({CommunityPersistentDraft draft, List<CommunityPostImageDraft> images})
  >
  loadMyCommunityDraft(String draftId) async {
    opened.add(draftId);
    final value = draft(indexFor(draftId));
    return (draft: value, images: photos.take(value.media.length).toList());
  }

  @override
  Future<String> saveMyCommunityDraft({
    required CommunityDraftSaveInput input,
    required List<CommunityPostImageDraft> images,
  }) async {
    saves++;
    saveInputs.add(input);
    saveImages.add(List.of(images));
    savedBodies[input.draftId] = input.body;
    if (loseNextSaveReply) {
      loseNextSaveReply = false;
      throw StateError('Synthetic reply lost after a private draft commit');
    }
    return input.draftId;
  }

  @override
  Future<CommunityProfile?> loadMyProfile() async {
    profileReads++;
    return null;
  }

  @override
  Future<CommunityPublicCode> loadPublicCode() async {
    codeReads++;
    throw StateError('No auto profile gate for Drafts');
  }

  @override
  Future<void> acceptContentPolicy(String version) async {
    policies++;
    throw StateError('No auto policy acceptance');
  }

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => CommunityPolicyState.accepted(
    CommunityContentPolicy.fromJson({
      'version': 'community-policy-v1',
      'locale_code': localeCode,
      'document_url': 'https://www.bilhealth.com/community-guidelines',
      'effective_at': '2026-09-08T00:00:00Z',
    }),
    acceptedVersion: 'community-policy-v1',
  );
  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [];
  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => const [
    CommunityCircle(
      slug: 'healthy-eating',
      titleCopyKey: 'community_circle_healthy_eating',
      descriptionCopyKey: 'community_circle_healthy_eating_body',
      rulesCopyKey: 'community_circle_standard_rules',
      access: CommunityCircleAccess.public,
      joinPolicy: CommunityCircleJoinPolicy.open,
      featured: true,
      memberCount: 8,
      postCount: 4,
      membershipStatus: CommunityCircleMembershipStatus.active,
    ),
  ];
  @override
  Future<bool> isCommunityModerator({bool forceRefresh = false}) async => false;
  @override
  Future<CommunityProfileOverview> loadProfileOverview(
    String userId,
  ) async => CommunityProfileOverview(
    userId: userId,
    displayName: arabic ? 'عضو تجريبي' : 'Sample member',
    isSelf: userId == _owner,
    relationship: userId == _owner
        ? CommunityRelationshipStatus.self
        : CommunityRelationshipStatus.none,
    allowFriendRequests: true,
    allowFollows: true,
    showFollowers: true,
    showFollowing: true,
    showFriends: false,
    showPosts: true,
    showMembershipTier: false,
    avatarUrl: 'https://reference.invalid/avatar',
    bio: arabic
        ? 'خطوات صغيرة لصحة أفضل وحياة أقوى. أشارك تجاربي اليومية مع المجتمع.'
        : 'Small steps for better health and a stronger life. Sharing everyday progress with the community.',
    countryCode: 'AU',
    handle: 'sample_member',
    followerCount: 1240,
    followingCount: 320,
    postCount: 24,
  );
  @override
  Future<String?> loadCommunityProfileCoverUrl(String userId) async =>
      'https://reference.invalid/cover';
  @override
  Future<CommunityCreatorProfile> loadCommunityCreatorProfile(
    String userId,
  ) async => CommunityCreatorProfile(
    userId: userId,
    contributor: true,
    approvedPosts: 24,
    followers: 1240,
    likesReceived: 231,
    commentsReceived: 64,
    qualifiedReferrals: 0,
    communityXp: 900,
    communityLevel: 4,
    currentLevelMinXp: 700,
    earnedBadgeCount: 1,
    totalBadgeCount: 1,
    badges: const [
      CommunityCreatorBadge(badgeKey: 'contributor', earned: true),
    ],
    certificationStatus: CommunityCreatorCertificationStatus.approved,
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
        id: _post,
        authorId: userId,
        authorName: arabic ? 'عضو تجريبي' : 'Sample member',
        authorAvatarUrl: 'https://reference.invalid/avatar',
        authorHandle: 'sample_member',
        body: body(0),
        createdAt: DateTime.utc(2026, 10, 6, 10),
        moderationStatus: CommunityPostModerationStatus.approved,
        likeCount: 24,
        commentCount: 12,
        media: [
          for (var index = 0; index < 4; index++)
            CommunityPostMedia(
              position: index,
              objectPath: '$_owner/$_post/$index.${photos[index].extension}',
              mimeType: photos[index].mimeType,
              bytes: photos[index].byteLength,
              width: photos[index].width,
              height: photos[index].height,
              url: 'https://reference.invalid/photo/$index',
            ),
        ],
      ),
    ],
    hasMore: false,
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
      canonicalName: arabic ? 'مراجعة معتمدة فعلية' : 'A real approved review',
      reviewNote: arabic
          ? 'وجبة متوازنة أشارك تجربتي معها.'
          : 'My experience with a balanced meal.',
      createdAt: DateTime.utc(2026, 10, 5),
    ),
  ];
  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> ids,
  ) async => {for (final id in ids) id: 298};
  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> ids) async => [
    for (final id in ids)
      CommunityPostReferenceMetadata(
        postId: id,
        title: title(0),
        hashtags: const ['healthyhabits'],
        topics: const [],
        collaborators: const [],
      ),
  ];
  @override
  Future<CommunityGoldBalance> loadGoldBalance() async =>
      throw StateError('Optional reward policy is unavailable');
  @override
  Future<List<CommunityQuest>> loadCommunityQuests() async => const [];
}
