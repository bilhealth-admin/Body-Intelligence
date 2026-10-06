part of 'community_circles_auth_session_test.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _postId = '33333333-3333-4333-8333-333333333333';
const _olderPostId = '44444444-4444-4444-8444-444444444444';
const _changedCopy = 'Your account changed. Return to Community to continue.';

CommunityCircle _circle(
  String slug, {
  CommunityCircleMembershipStatus? membership,
}) => CommunityCircle(
  slug: slug,
  titleCopyKey: 'community_circle_${slug.replaceAll('-', '_')}',
  descriptionCopyKey: 'community_circle_${slug.replaceAll('-', '_')}_body',
  rulesCopyKey: 'community_circle_standard_rules',
  access: CommunityCircleAccess.public,
  joinPolicy: CommunityCircleJoinPolicy.open,
  featured: false,
  memberCount: 17,
  postCount: 4,
  membershipStatus: membership,
  membershipRole: membership == null
      ? null
      : CommunityCircleMembershipRole.member,
);

class _CircleAuthFixture {
  String owner = _ownerA;
  final sessions = <String, String>{};
  final requests = <({String method, String owner, String? slug})>[];
  Completer<void>? pendingMembership;

  late final client = SupabaseClient(
    'https://circles-auth.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(MockClient(_respond)),
  );

  Future<http.Response> _respond(http.Request request) async {
    Object body;
    if (request.url.path == '/auth/v1/token') {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      body = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': owner,
          'email': 'circles@example.invalid',
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
      final token = request.headers['authorization']!.split(' ').last;
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map<String, dynamic>;
      final params = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add((
        method: method,
        owner: claims['sub'] as String,
        slug: params['p_slug'] as String?,
      ));
      if (method == 'bil_join_community_circle_v1' ||
          method == 'bil_leave_community_circle_v1') {
        await pendingMembership?.future;
      }
      body = switch (method) {
        'bil_join_community_circle_v1' => 'active',
        'bil_leave_community_circle_v1' => true,
        _ => throw StateError('Unexpected fixture RPC: $method'),
      };
    } else {
      throw StateError('Unexpected fixture request: ${request.url}');
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  Future<void> signIn(String nextOwner) async {
    owner = nextOwner;
    await client.auth.signInWithPassword(
      email: 'circles@example.invalid',
      password: 'synthetic',
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

class _CircleRepository extends CommunityRepository {
  _CircleRepository(super.client, {this.prefix = ''});

  final String prefix;
  final calls = <({String method, String owner, String target})>[];
  List<CommunityCircle> circles = [_circle('healthy-eating')];
  Completer<List<CommunityCircle>>? pendingList;
  Completer<CommunityCirclePostBatch>? pendingPage;
  Completer<Map<String, int>>? pendingCounts;
  bool failList = false;
  bool hasMore = false;

  void record(String method, String target) {
    calls.add((method: method, owner: currentUserId, target: target));
  }

  int count(String method) =>
      calls.where((call) => call.method == method).length;

  @override
  bool get useServerCommunityReferenceParity => true;

  CommunityCirclePostBatch page(String slug, {bool older = false}) =>
      CommunityCirclePostBatch(
        posts: [
          CommunityPost(
            id: older ? _olderPostId : _postId,
            authorId: _ownerB,
            authorName: 'A real circle member',
            body: '$prefix$slug ${older ? 'older' : 'first'} post',
            createdAt: DateTime.utc(2026, 10, older ? 3 : 4),
            moderationStatus: CommunityPostModerationStatus.approved,
          ),
        ],
        hasMore: !older && hasMore,
        nextBefore: DateTime.utc(2026, 10, 4),
        nextBeforeId: _postId,
      );

  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async {
    record('list', '');
    final pending = pendingList;
    pendingList = null;
    if (pending != null) return pending.future;
    if (failList) throw StateError('Synthetic circle transport detail');
    return circles;
  }

  @override
  Future<CommunityCirclePostBatch> loadCommunityCirclePosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    record(before == null ? 'first' : 'older', slug);
    final pending = pendingPage;
    pendingPage = null;
    return pending == null ? page(slug, older: before != null) : pending.future;
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
}

Future<void> _roundTrip(WidgetTester tester, _CircleAuthFixture auth) async {
  final delivered = <({String? eventOwner, String? currentOwner})>[];
  final subscription = auth.client.auth.onAuthStateChange.listen((state) {
    delivered.add((
      eventOwner: state.session?.user.id,
      currentOwner: auth.client.auth.currentUser?.id,
    ));
  });
  // A root-zone stream cancellation is disposed by the outer runner so it
  // cannot strand the following fake-clock pump.
  addTearDown(subscription.cancel);
  await auth.roundTrip();
  await tester.pump();
  expect(delivered, contains((eventOwner: _ownerB, currentOwner: _ownerA)));
}

Future<void> _changeOwner(
  WidgetTester tester,
  _CircleAuthFixture auth,
  bool returnToA,
) async {
  if (returnToA) {
    await _roundTrip(tester, auth);
  } else {
    await auth.recover(_ownerB);
    await tester.pump();
  }
}

Future<void> _mountList(
  WidgetTester tester,
  _CircleRepository repository, {
  bool settle = true,
  Future<void> Function(String)? onCompose,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CommunityCirclesPage(
        key: const Key('stable-circle-list'),
        repository: repository,
        onComposeCircle: onCompose,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _mountCircle(
  WidgetTester tester,
  _CircleRepository repository, {
  String slug = 'healthy-eating',
  bool settle = true,
  Future<void> Function(String)? onCompose,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CommunityCirclePage(
        key: const Key('stable-circle-detail'),
        repository: repository,
        circle: _circle(
          slug,
          membership: CommunityCircleMembershipStatus.active,
        ),
        onComposeCircle: onCompose,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}
