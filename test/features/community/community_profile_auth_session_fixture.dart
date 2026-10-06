part of 'community_profile_auth_session_test.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _member = '33333333-3333-4333-8333-333333333333';
const _postId = '44444444-4444-4444-8444-444444444444';
const _connection = '55555555-5555-4555-8555-555555555555';
const _option = '66666666-6666-4666-8666-666666666666';
const _changedCopy = 'Your account changed. Return to Community to continue.';

class _ProfileAuthFixture {
  String owner = _ownerA;
  final sessions = <String, String>{};
  final dataRequests = <String>[];
  late final client = SupabaseClient(
    'https://profile-auth.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(
      MockClient((request) async {
        Object body;
        if (request.url.path == '/auth/v1/token') {
          final payload = base64Url
              .encode(
                utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})),
              )
              .replaceAll('=', '');
          body = {
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': owner,
              'email': 'profile-fixture@example.invalid',
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-10-06T00:00:00Z',
            },
          };
        } else if (request.url.path == '/auth/v1/logout') {
          body = {};
        } else if (request.url.path.startsWith('/rest/v1/rpc/')) {
          final method = request.url.pathSegments.last;
          dataRequests.add(method);
          body = switch (method) {
            'bil_social_like_v2' => {
              'post_id': _postId,
              'liked': true,
              'like_count': 1,
              'comment_count': 0,
            },
            'bil_social_save_v2' => {'post_id': _postId, 'saved': true},
            'bil_social_request_friend_v2' => 'pending',
            'bil_vote_community_poll_v1' => _pollJson(selected: true),
            'bil_social_stats_v2' => [
              {
                'post_id': _postId,
                'liked': false,
                'like_count': 0,
                'comment_count': 0,
              },
            ],
            _ => throw StateError('Unexpected external RPC: $method'),
          };
        } else {
          throw StateError('Unexpected external request: ${request.url.path}');
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    ),
  );

  Future<void> signIn(String nextOwner) async {
    owner = nextOwner;
    await client.auth.signInWithPassword(
      email: 'profile-fixture@example.invalid',
      password: 'synthetic-password',
    );
    sessions[owner] = jsonEncode(client.auth.currentSession!.toJson());
  }

  Future<void> recover(String nextOwner) async {
    await client.auth.recoverSession(sessions[nextOwner]!);
  }

  Future<void> roundTrip() async {
    final second = client.auth.recoverSession(sessions[_ownerB]!);
    final first = client.auth.recoverSession(sessions[_ownerA]!);
    await Future.wait([second, first]);
  }
}

CommunityProfileOverview _profile(String userId, {String prefix = ''}) =>
    CommunityProfileOverview(
      userId: userId,
      displayName:
          '$prefix${userId == _ownerA ? 'Private A' : 'Public member'}',
      isSelf: userId == _ownerA,
      relationship: CommunityRelationshipStatus.none,
      allowFriendRequests: true,
      allowFollows: true,
      showFollowers: true,
      showFollowing: true,
      showFriends: true,
      showPosts: true,
      showMembershipTier: false,
      handle: userId == _ownerA ? 'owner_a' : 'public_member',
      followerCount: 12,
      followingCount: 6,
      friendCount: 4,
      postCount: 1,
      communityXp: 900,
      communityLevel: 4,
      communityLevelCopyKey: 'community_level_4',
      currentLevelMinXp: 700,
      viewerFollows: false,
      followsViewer: false,
    );

CommunityCreatorProfile _creator(String userId) => CommunityCreatorProfile(
  userId: userId,
  contributor: false,
  approvedPosts: 1,
  followers: 12,
  likesReceived: 3,
  commentsReceived: 2,
  qualifiedReferrals: 0,
  communityXp: 900,
  communityLevel: 4,
  currentLevelMinXp: 700,
  earnedBadgeCount: 0,
  totalBadgeCount: 0,
  badges: const [],
  certificationStatus: CommunityCreatorCertificationStatus.notCertified,
);

class _ProfileRepository extends CommunityRepository {
  _ProfileRepository(super.client, {this.prefix = ''});

  final String prefix;
  final calls = <({String method, String owner, String target})>[];
  Completer<CommunityProfileOverview>? pendingOverview;
  Completer<void>? pendingFollow;
  Completer<void>? pendingFriend;
  Completer<List<CommunityProfileConnection>>? pendingConnections;
  Completer<void>? pendingLike;
  Completer<void>? pendingSave;
  Completer<void>? pendingStats;
  Completer<void>? pendingVote;
  bool includePoll = false;
  bool useSdkFriend = false;
  int deletes = 0;
  int follows = 0;
  int requests = 0;

  void record(String method, String target) =>
      calls.add((method: method, owner: currentUserId, target: target));

  int count(String method) =>
      calls.where((call) => call.method == method).length;

  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async {
    record('profile', userId);
    final pending = pendingOverview;
    pendingOverview = null;
    return pending == null ? _profile(userId, prefix: prefix) : pending.future;
  }

  @override
  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    record('posts', userId);
    return CommunityFeedBatch(
      posts: [
        CommunityPost(
          id: _postId,
          authorId: userId,
          authorName: 'Post author',
          body:
              '$prefix${userId == _ownerA ? 'Private A post' : 'Public post'}',
          createdAt: DateTime.utc(2026, 10, 3, 12),
          moderationStatus: CommunityPostModerationStatus.approved,
          authorRelationship: CommunityRelationshipStatus.none,
          authorCanRequest: true,
          poll: includePoll ? CommunityPoll.fromJson(_pollJson()) : null,
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<CommunityCreatorProfile> loadCommunityCreatorProfile(
    String userId,
  ) async {
    record('creator', userId);
    return _creator(userId);
  }

  @override
  Future<List<CommunityProfileReview>> loadCommunityProfileReviews({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    record('reviews', userId);
    return [];
  }

  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async {
    record('drafts', currentUserId);
    return [];
  }

  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(List<String> ids) async {
    record('views', ids.join(','));
    return {};
  }

  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> ids) async {
    record('metadata', ids.join(','));
    return [];
  }

  @override
  Future<String?> loadCommunityProfileCoverUrl(String userId) async {
    record('cover', userId);
    return null;
  }

  @override
  Future<CommunityGoldBalance> loadGoldBalance() async {
    record('rewards', currentUserId);
    throw StateError('Synthetic optional rewards unavailable');
  }

  @override
  Future<List<CommunityQuest>> loadCommunityQuests() async {
    record('quests', currentUserId);
    return [];
  }

  @override
  Future<void> follow(String userId) async {
    record('follow', userId);
    follows++;
    final pending = pendingFollow;
    pendingFollow = null;
    if (pending != null) await pending.future;
  }

  @override
  Future<CommunityFriendRequestStatus> requestFriend(String userId) async {
    record('friend', userId);
    requests++;
    final pending = pendingFriend;
    pendingFriend = null;
    if (pending != null) await pending.future;
    if (useSdkFriend) return super.requestFriend(userId);
    return CommunityFriendRequestStatus.pending;
  }

  @override
  Future<void> deletePost(String postId) async {
    record('delete', postId);
    deletes++;
  }

  @override
  Future<CommunityPostStats> setPostLiked(
    String postId, {
    required bool liked,
  }) async {
    record('like-start', postId);
    final pending = pendingLike;
    pendingLike = null;
    if (pending != null) await pending.future;
    return super.setPostLiked(postId, liked: liked);
  }

  @override
  Future<CommunitySavedState> setPostSaved(
    String postId, {
    required bool saved,
  }) async {
    record('save-start', postId);
    final pending = pendingSave;
    pendingSave = null;
    if (pending != null) await pending.future;
    return super.setPostSaved(postId, saved: saved);
  }

  @override
  Future<List<CommunityPostStats>> loadPostStats(List<String> ids) async {
    record('stats-start', ids.join(','));
    final pending = pendingStats;
    pendingStats = null;
    if (pending != null) await pending.future;
    return super.loadPostStats(ids);
  }

  @override
  Future<List<CommunityCommentThread>> loadPostCommentThreads(
    String postId, {
    DateTime? after,
    String? afterId,
    int limit = 30,
  }) async => [];

  @override
  Future<Map<String, String>> loadVisibleMembershipTiers(
    List<String> ids,
  ) async => {};

  @override
  Future<int> recordCommunityPostView(String postId) async => 0;

  @override
  Future<CommunityPoll> voteCommunityPoll({
    required String postId,
    required List<String> optionIds,
  }) async {
    record('vote-start', postId);
    final pending = pendingVote;
    pendingVote = null;
    if (pending != null) await pending.future;
    return super.voteCommunityPoll(postId: postId, optionIds: optionIds);
  }

  @override
  Future<bool> isCommunityModerator({bool forceRefresh = false}) async => false;

  @override
  Future<List<CommunityProfileConnection>> loadProfileConnections({
    required String userId,
    required CommunityProfileConnectionKind kind,
    DateTime? before,
    String? beforeUserId,
    int limit = 40,
  }) async {
    record('connections', userId);
    final pending = pendingConnections;
    pendingConnections = null;
    return pending == null ? connectionRows : pending.future;
  }

  List<CommunityProfileConnection> get connectionRows => [
    CommunityProfileConnection(
      userId: _connection,
      displayName: 'A private connection',
      relationship: CommunityRelationshipStatus.none,
      connectedAt: DateTime.utc(2026, 10, 1),
      allowFollows: true,
    ),
  ];
}

Map<String, dynamic> _pollJson({bool selected = false}) => {
  'post_id': _postId,
  'question': 'Recovery day?',
  'allow_multiple': false,
  'closed': false,
  'total_votes': selected ? 1 : 0,
  'options': [
    {
      'id': _option,
      'position': 0,
      'text': 'Walk',
      'vote_count': selected ? 1 : 0,
      'selected': selected,
    },
    {
      'id': '77777777-7777-4777-8777-777777777777',
      'position': 1,
      'text': 'Rest',
      'vote_count': 0,
      'selected': false,
    },
  ],
};
