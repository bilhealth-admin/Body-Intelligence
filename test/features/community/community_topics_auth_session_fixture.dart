part of 'community_topics_auth_session_test.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _postId = '33333333-3333-4333-8333-333333333333';
const _olderPostId = '44444444-4444-4444-8444-444444444444';
const _slug = 'success-stories';
const _changedCopy = 'Your account changed. Return to Community to continue.';

Map<String, dynamic> _session(String owner, {bool expired = false}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': owner, 'exp': expired ? 1600000000 : 4102444800}),
        ),
      )
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'synthetic-refresh-$owner',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'email': 'topics@example.invalid',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'created_at': '2026-10-06T00:00:00Z',
    },
  };
}

String? _requestOwner(http.Request request) {
  final token = request.headers['authorization']?.split(' ').last;
  if (token == null || token.split('.').length != 3) return null;
  final claims =
      jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.')[1])),
            ),
          )
          as Map<String, dynamic>;
  return claims['sub'] as String?;
}

class _TopicAuthFixture {
  final sessions = {
    _ownerA: jsonEncode(_session(_ownerA)),
    _ownerB: jsonEncode(_session(_ownerB)),
  };
  final requests = <({String method, String? owner, String? slug})>[];
  Completer<void>? pendingList;
  Completer<void>? pendingFollow;
  Completer<void>? pendingRefresh;
  Completer<void>? refreshEntered;
  String responseSlug = _slug;
  bool failFollow = false;
  bool responseFeatured = false;

  late final client = SupabaseClient(
    'https://topics-auth.invalid',
    'synthetic-topics-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(MockClient(_respond)),
  );

  Future<http.Response> _respond(http.Request request) async {
    Object? body;
    var status = 200;
    if (request.url.path == '/auth/v1/token') {
      final entered = refreshEntered;
      if (entered != null && !entered.isCompleted) entered.complete();
      await pendingRefresh?.future;
      body = _session(_ownerA);
    } else if (request.url.path == '/auth/v1/logout') {
      body = <String, Object?>{};
    } else if (request.url.path.startsWith('/rest/v1/rpc/')) {
      final method = request.url.pathSegments.last;
      final owner = _requestOwner(request);
      final params =
          (jsonDecode(request.body) as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      requests.add((
        method: method,
        owner: owner,
        slug: params['p_slug'] as String?,
      ));
      if (owner == null) {
        status = 403;
        body = {
          'code': '42501',
          'message': 'authentication_required',
          'details': null,
          'hint': null,
        };
      } else if (method == 'bil_list_community_topics_v1') {
        final slug = responseSlug;
        final pending = pendingList;
        pendingList = null;
        await pending?.future;
        body = [
          {
            'slug': slug,
            'title_copy_key': 'community_topic_success_stories',
            'description_copy_key': 'community_topic_success_stories_body',
            'icon_key': 'trophy',
            'featured': responseFeatured,
            'follower_count': 17,
            'post_count': 4,
            'following': false,
          },
        ];
      } else if (method == 'bil_follow_community_topic_v1') {
        await pendingFollow?.future;
        if (failFollow) {
          status = 503;
          body = {
            'code': 'fixture_failure',
            'message': 'Synthetic server error',
            'details': null,
            'hint': null,
          };
        } else {
          body = params['p_follow'] as bool;
        }
      } else {
        throw StateError('Unexpected topic fixture RPC: $method');
      }
    } else {
      throw StateError('Unexpected fixture request: ${request.url}');
    }
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  int count(String method) =>
      requests.where((request) => request.method == method).length;

  Future<void> recover(String owner) async {
    await client.auth.recoverSession(sessions[owner]!);
  }

  Future<void> roundTrip() async {
    final second = client.auth.recoverSession(sessions[_ownerB]!);
    final first = client.auth.recoverSession(sessions[_ownerA]!);
    await Future.wait([second, first]);
  }
}

class _TopicRepository extends CommunityRepository {
  _TopicRepository(super.client);

  final String prefix = '';
  final calls = <({String method, String owner, String target})>[];
  Completer<CommunityTopicPostBatch>? pendingPage;
  Completer<Map<String, int>>? pendingCounts;
  bool hasMore = false;
  int detailLoads = 0;
  bool includeFeedPost = false;

  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async => null;

  @override
  Future<bool> isCommunityModerator() async => false;

  @override
  Future<CommunityAttention> loadAttention() async =>
      const CommunityAttention();

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    final policy = CommunityContentPolicy.fromJson({
      'version': 'topics-fixture-v1',
      'locale_code': localeCode,
      'document_url': 'https://topics-policy.invalid/community',
      'effective_at': '2026-10-01T00:00:00Z',
    });
    return CommunityPolicyState.accepted(
      policy,
      acceptedVersion: policy.version,
    );
  }

  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedCachedFirst({
    required CommunityFeedMode mode,
    required String locale,
    required bool Function() current,
    required void Function(CommunityFeedModeBatch) onRefresh,
    required void Function() onRefreshing,
    required void Function(Object) onRefreshError,
    int limit = 40,
  }) async {
    final posts = includeFeedPost ? page().posts : const <CommunityPost>[];
    return CommunityFeedModeBatch(
      posts: posts,
      references: [
        for (final post in posts)
          CommunityFeedReference(
            postId: post.id,
            createdAt: post.createdAt,
            priority: 0,
            reasons: const [],
          ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> postIds) async => [
    for (final id in postIds)
      CommunityPostReferenceMetadata(
        postId: id,
        title: 'Synthetic topic source',
        hashtags: const [],
        collaborators: const [],
        topics: const [
          CommunityPostTopicReference(
            slug: _slug,
            titleCopyKey: 'community_topic_success_stories',
            postCount: 4,
          ),
        ],
      ),
  ];

  @override
  Future<Map<String, CommunityComment>> loadCommunityFeedCommentPreviews(
    List<String> postIds,
  ) async => const {};

  void record(String method, String target) {
    calls.add((method: method, owner: currentUserId, target: target));
  }

  int count(String method) =>
      calls.where((call) => call.method == method).length;

  @override
  bool get useServerCommunityReferenceParity => true;

  CommunityTopicPostBatch page({bool older = false}) => CommunityTopicPostBatch(
    posts: [
      CommunityPost(
        id: older ? _olderPostId : _postId,
        authorId: _ownerA,
        authorName: 'Synthetic topic author',
        body: '$prefix$_slug ${older ? 'older' : 'first'} post',
        createdAt: DateTime.utc(2026, 10, older ? 3 : 4),
        moderationStatus: CommunityPostModerationStatus.approved,
      ),
    ],
    hasMore: !older && hasMore,
    nextBefore: DateTime.utc(2026, 10, 4),
    nextBeforeId: _postId,
  );

  @override
  Future<CommunityTopicPostBatch> loadCommunityTopicPosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    record(before == null ? 'first' : 'older', slug);
    final pending = pendingPage;
    pendingPage = null;
    return pending == null ? page(older: before != null) : pending.future;
  }

  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> postIds,
  ) async {
    record('counts', postIds.join(','));
    final pending = pendingCounts;
    pendingCounts = null;
    return pending == null
        ? {for (final id in postIds) id: 37}
        : pending.future;
  }

  @override
  Future<List<CommunityPostStats>> loadPostStats(List<String> postIds) async {
    detailLoads++;
    return [
      for (final id in postIds)
        CommunityPostStats(
          postId: id,
          likeCount: 0,
          liked: false,
          commentCount: 0,
        ),
    ];
  }

  @override
  Future<List<CommunityCommentThread>> loadPostCommentThreads(
    String postId, {
    DateTime? after,
    String? afterId,
    int limit = 20,
  }) async => const [];

  @override
  Future<int> recordCommunityPostView(String postId) async => 38;

  @override
  Future<Map<String, String>> loadVisibleMembershipTiers(
    List<String> userIds,
  ) async => const {};

  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async =>
      CommunityProfileOverview.fromProfile(
        CommunityProfile(
          userId: userId,
          displayName: 'Synthetic topic author',
          localeCode: 'en',
          discoverable: true,
        ),
      );
}

Future<void> _changeOwner(
  WidgetTester tester,
  _TopicAuthFixture auth, {
  required bool returnToA,
}) async {
  if (!returnToA) {
    await auth.recover(_ownerB);
    await tester.pump();
    return;
  }
  final delivered = <({String? eventOwner, String? currentOwner})>[];
  final subscription = auth.client.auth.onAuthStateChange.listen((state) {
    delivered.add((
      eventOwner: state.session?.user.id,
      currentOwner: auth.client.auth.currentUser?.id,
    ));
  });
  addTearDown(subscription.cancel);
  await auth.roundTrip();
  await tester.pump();
  expect(delivered, contains((eventOwner: _ownerB, currentOwner: _ownerA)));
}

Future<void> _mountTopics(
  WidgetTester tester,
  _TopicRepository repository, {
  bool settle = true,
  Future<void> Function(String)? onCompose,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: CommunityTopicsPage(
          key: const Key('stable-topics-list'),
          repository: repository,
          onComposeTopic: onCompose,
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _openTopic(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(find.byType(InkWell).first);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Finder get _followButton =>
    find.byKey(const Key('community-topic-follow-$_slug'));
Finder get _postTile => find
    .ancestor(
      of: find.text('$_slug first post'),
      matching: find.byType(InkWell),
    )
    .first;

Future<void> _mountHub(WidgetTester tester, _TopicRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: CommunityHubPage(
          repository: repository,
          client: repository.communitySocialClient,
          entryWelcomeHandled: true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
