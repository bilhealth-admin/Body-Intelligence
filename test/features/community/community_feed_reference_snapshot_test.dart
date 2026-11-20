import 'dart:async';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _postId = '33333333-3333-4333-8333-333333333333';
CommunityPost _post({
  String body = 'Stable authorized body',
  String author = _owner,
}) => CommunityPost(
  id: _postId,
  authorId: author,
  body: body,
  createdAt: DateTime.utc(2026, 11, 20),
);
CommunityFeedModeBatch _page(List<CommunityPost> posts) =>
    CommunityFeedModeBatch(posts: posts, hasMore: false, references: const []);
List<CommunityPostReferenceMetadata> _references(String title) => [
  CommunityPostReferenceMetadata(
    postId: _postId,
    title: title,
    hashtags: const ['Food', 'Fitness', 'Health'],
    collaborators: const [],
  ),
];

// Deferred repository responses model authorized server snapshots. This fixture
// exercises real feed widgets and continuations; it does not make cloud writes.
class _SnapshotRepository extends CommunityRepository {
  _SnapshotRepository(super.client, {this.owner = _owner});
  final String owner;
  CommunityFeedModeBatch page = _page([_post()]);
  bool deferReferences = false;
  int firstPageReads = 0;
  bool topicFixture = false;
  Completer<CommunityTopicPostBatch>? topicPage;
  Completer<CommunityFeedModeBatch>? deferredFirstPage;
  final pending = <Completer<List<CommunityPostReferenceMetadata>>>[];
  late void Function(CommunityFeedModeBatch) refresh;
  @override
  String get currentUserId => owner;
  @override
  bool get useServerCommunityReferenceParity => true;
  @override
  bool get useServerRankedCommunityFeed => false;
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<CommunityProfile?> loadMyProfile() async => CommunityProfile(
    userId: owner,
    displayName: 'Fixture member',
    localeCode: 'en',
    discoverable: false,
  );
  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async =>
      CommunityProfileOverview.fromProfile((await loadMyProfile())!);
  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => topicFixture
      ? const [
          CommunityTopic(
            slug: 'nutrition',
            titleCopyKey: 'topic_title',
            descriptionCopyKey: 'topic_description',
            iconKey: 'group',
            featured: false,
            followerCount: 0,
            postCount: 1,
            following: false,
          ),
        ]
      : const [];
  @override
  Future<CommunityTopicPostBatch> loadCommunityTopicPosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async =>
      topicPage?.future ??
      CommunityTopicPostBatch(posts: [_post()], hasMore: false);
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    final policy = CommunityContentPolicy.fromJson({
      'version': 'fixture-policy',
      'locale_code': localeCode,
      'document_url': 'https://policy.invalid/community',
      'effective_at': '2026-11-01T00:00:00Z',
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
    required VoidCallback onRefreshing,
    required void Function(Object) onRefreshError,
    int limit = 40,
  }) async {
    firstPageReads++;
    refresh = (value) {
      if (current()) onRefresh(value);
    };
    return deferredFirstPage?.future ?? page;
  }

  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> ids) {
    expect(ids, [_postId]);
    if (!deferReferences) {
      return Future.value(_references('Original complete title'));
    }
    final result = Completer<List<CommunityPostReferenceMetadata>>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<List<CommunityPostAuthorIdentity>> loadPostAuthorIdentities(
    List<String> ids,
  ) async => const [];
  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> ids,
  ) async => const {};
  @override
  Future<Map<String, CommunityComment>> loadCommunityFeedCommentPreviews(
    List<String> ids,
  ) async => const {};
  @override
  Future<Map<String, String>> loadVisibleMembershipTiers(
    List<String> ids,
  ) async => const {};
}

late SupabaseClient _fixtureClient;
_SnapshotRepository _repository({String owner = _owner}) =>
    _SnapshotRepository(_fixtureClient, owner: owner);

Future<void> _mount(WidgetTester tester, _SnapshotRepository repository) async {
  tester.view.physicalSize = const Size(450, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: CommunityHubPage(repository: repository, entryWelcomeHandled: true),
    ),
  );
  await tester.pumpAndSettle();
}

void _complete(
  _SnapshotRepository repository,
  int index,
  List<CommunityPostReferenceMetadata> values,
) => repository.pending[index].complete(values);

void main() {
  // Match the existing native feed fixtures: isolate/auth resources are created
  // and disposed in the test runner's real async lifecycle, outside FakeAsync.
  setUp(() {
    _fixtureClient = SupabaseClient(
      'https://reference-snapshot.invalid',
      'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() async => _fixtureClient.dispose());

  testWidgets('held first metadata publishes body and title together', (
    tester,
  ) async {
    final repository = _repository()..deferReferences = true;
    tester.view.physicalSize = const Size(450, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityHubPage(
          repository: repository,
          entryWelcomeHandled: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(repository.pending, hasLength(1));
    expect(find.text('Stable authorized body'), findsNothing);
    _complete(repository, 0, _references('Complete first title'));
    await tester.pumpAndSettle();
    expect(find.text('Complete first title'), findsOneWidget);
    expect(find.text('Stable authorized body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'same owner refresh keeps complete post geometry while metadata is held',
    (tester) async {
      final repository = _repository();
      await _mount(tester, repository);
      final body = find.text('Stable authorized body');
      final before = tester.getRect(body);
      repository.deferReferences = true;
      repository.refresh(_page([_post()]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Original complete title'), findsOneWidget);
      expect(tester.getRect(body), before);
      _complete(repository, 0, _references('Original complete title'));
      await tester.pumpAndSettle();
      expect(tester.getRect(body), before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'successful empty metadata removes an old title and all tags atomically',
    (tester) async {
      final repository = _repository();
      await _mount(tester, repository);
      repository.deferReferences = true;
      repository.refresh(_page([_post()]));
      await tester.pump();
      expect(find.text('Original complete title'), findsOneWidget);
      _complete(repository, 0, const []);
      await tester.pumpAndSettle();
      expect(find.text('Original complete title'), findsNothing);
      expect(find.text('#Food'), findsNothing);
      expect(find.text('Stable authorized body'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fresh authorization removes posts immediately before old metadata resolves',
    (tester) async {
      final repository = _repository();
      await _mount(tester, repository);
      repository.deferReferences = true;
      repository.refresh(_page([_post()]));
      await tester.pump();
      repository.refresh(_page(const []));
      await tester.pump();
      expect(find.text('Original complete title'), findsNothing);
      expect(find.text('Stable authorized body'), findsNothing);
      _complete(repository, 0, _references('Retired private title'));
      await tester.pumpAndSettle();
      expect(find.text('Retired private title'), findsNothing);
      expect(find.text('Stable authorized body'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final changedAuthor in [false, true]) {
    testWidgets(
      'changed ${changedAuthor ? 'author' : 'body'} never receives the old revision title',
      (tester) async {
        final repository = _repository();
        await _mount(tester, repository);
        final desiredBody = changedAuthor
            ? 'Stable authorized body'
            : 'New authorized body';
        repository.deferReferences = true;
        repository.refresh(
          _page([
            _post(
              body: desiredBody,
              author: changedAuthor
                  ? '22222222-2222-4222-8222-222222222222'
                  : _owner,
            ),
          ]),
        );
        await tester.pump();
        expect(find.text('Original complete title'), findsNothing);
        expect(find.text('Stable authorized body'), findsNothing);
        expect(find.text('New authorized body'), findsNothing);
        _complete(repository, 0, _references('New revision title'));
        await tester.pumpAndSettle();
        expect(find.text('New revision title'), findsOneWidget);
        expect(find.text(desiredBody), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'latest same-generation metadata wins over a late cached-refresh read',
    (tester) async {
      final repository = _repository();
      await _mount(tester, repository);
      repository.deferReferences = true;
      repository.refresh(_page([_post()]));
      await tester.pump();
      repository.refresh(_page([_post(body: 'Latest authorized body')]));
      await tester.pump();
      expect(repository.pending, hasLength(2));
      _complete(repository, 1, _references('Latest title'));
      await tester.pumpAndSettle();
      _complete(repository, 0, _references('Obsolete title'));
      await tester.pumpAndSettle();
      expect(find.text('Latest title'), findsOneWidget);
      expect(find.text('Latest authorized body'), findsOneWidget);
      expect(find.text('Obsolete title'), findsNothing);
      expect(find.text('Stable authorized body'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'retired owner metadata cannot repopulate the replacement owner feed',
    (tester) async {
      final repository = _repository();
      await _mount(tester, repository);
      repository.deferReferences = true;
      repository.refresh(_page([_post()]));
      await tester.pump();
      final next = _repository(owner: '22222222-2222-4222-8222-222222222222');
      next.page = _page([
        _post(body: 'Replacement owner body', author: next.owner),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityHubPage(repository: next, entryWelcomeHandled: true),
        ),
      );
      await tester.pumpAndSettle();
      _complete(repository, 0, _references('Retired owner secret title'));
      await tester.pumpAndSettle();
      expect(find.text('Replacement owner body'), findsOneWidget);
      expect(find.text('Stable authorized body'), findsNothing);
      expect(find.text('Retired owner secret title'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed optional metadata preserves authorized complete content without fabricating removals',
    (tester) async {
      final repository = _repository();
      await _mount(tester, repository);
      final before = tester.getRect(find.text('Stable authorized body'));
      repository.deferReferences = true;
      repository.refresh(_page([_post()]));
      await tester.pump();
      repository.pending[0].completeError(
        StateError('Synthetic metadata outage'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Original complete title'), findsOneWidget);
      expect(tester.getRect(find.text('Stable authorized body')), before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'retired A metadata does not revive after an A B A repository visit',
    (tester) async {
      final a = _repository();
      await _mount(tester, a);
      a.deferReferences = true;
      a.refresh(_page([_post()]));
      await tester.pump();
      final b = _repository(owner: '22222222-2222-4222-8222-222222222222');
      b.page = _page([_post(body: 'B authorized body', author: b.owner)]);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityHubPage(repository: b, entryWelcomeHandled: true),
        ),
      );
      await tester.pumpAndSettle();
      a.page = _page([_post(body: 'Fresh A body')]);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityHubPage(repository: a, entryWelcomeHandled: true),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(a.pending, hasLength(2));
      _complete(a, 1, _references('Fresh A title'));
      await tester.pumpAndSettle();
      _complete(a, 0, _references('Retired A secret title'));
      await tester.pumpAndSettle();
      expect(find.text('Fresh A body'), findsOneWidget);
      expect(find.text('Fresh A title'), findsOneWidget);
      expect(find.text('Retired A secret title'), findsNothing);
      expect(find.text('Stable authorized body'), findsNothing);
      expect(find.text('B authorized body'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fresh cached callback supersedes an unresolved older first page',
    (tester) async {
      final repository = _repository()
        ..deferReferences = true
        ..deferredFirstPage = Completer<CommunityFeedModeBatch>();
      tester.view.physicalSize = const Size(450, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityHubPage(
            repository: repository,
            entryWelcomeHandled: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      repository.refresh(_page([_post(body: 'Fresh callback body')]));
      await tester.pump();
      repository.deferredFirstPage!.complete(_page([_post()]));
      await tester.pump();
      expect(repository.pending, hasLength(1));
      expect(find.text('Stable authorized body'), findsNothing);
      _complete(repository, 0, _references('Fresh callback title'));
      await tester.pumpAndSettle();
      expect(find.text('Fresh callback title'), findsOneWidget);
      expect(find.text('Fresh callback body'), findsOneWidget);
      expect(find.text('Stable authorized body'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'late old topic revision cannot replace hidden fresh All references',
    (tester) async {
      final repository = _repository()
        ..topicFixture = true
        ..topicPage = Completer<CommunityTopicPostBatch>();
      await _mount(tester, repository);
      await tester.tap(find.byKey(const Key('community-category-nutrition')));
      await tester.pump();
      repository.deferReferences = true;
      repository.refresh(_page([_post(body: 'Fresh All revision body')]));
      await tester.pump();
      expect(repository.pending, hasLength(1));
      // The topic response is older than the pending authoritative All revision.
      // Its enrichment starts later, so a mere last-request ID serial is unsafe.
      repository.topicPage!.complete(
        CommunityTopicPostBatch(posts: [_post()], hasMore: false),
      );
      await tester.pump();
      await tester.pump();
      expect(
        repository.pending,
        hasLength(1),
        reason:
            'Old topic revision must not supersede the fresh All metadata request',
      );
      _complete(repository, 0, _references('Fresh All revision title'));
      await tester.pumpAndSettle();
      expect(find.text('Stable authorized body'), findsOneWidget);
      expect(
        find.text('Fresh All revision title'),
        findsNothing,
        reason: 'New title cannot decorate the old topic body',
      );
      await tester.tap(find.byKey(const Key('community-category-all')));
      await tester.pumpAndSettle();
      expect(find.text('Fresh All revision body'), findsOneWidget);
      expect(find.text('Fresh All revision title'), findsOneWidget);
      expect(find.text('Stable authorized body'), findsNothing);
      expect(find.text('Original complete title'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mode cache does not pair an old body with a newer shared reference revision',
    (tester) async {
      final repository = _repository();
      await _mount(tester, repository);
      repository.deferReferences = true;
      repository.page = _page([_post(body: 'Following current body')]);
      await tester.tap(find.byKey(const Key('community-hub-following-tab')));
      await tester.pump();
      _complete(repository, 0, _references('Following current title'));
      await tester.pumpAndSettle();
      expect(find.text('Following current body'), findsOneWidget);
      repository.page = _page([_post(body: 'Fresh Explore server body')]);
      await tester.tap(find.byKey(const Key('community-hub-explore-tab')));
      await tester.pump();
      expect(
        repository.firstPageReads,
        3,
        reason:
            'Cached Explore revision must not reuse the newer Following metadata',
      );
      expect(find.text('Stable authorized body'), findsNothing);
      expect(repository.pending, hasLength(2));
      _complete(repository, 1, _references('Fresh Explore server title'));
      await tester.pumpAndSettle();
      expect(find.text('Fresh Explore server body'), findsOneWidget);
      expect(find.text('Fresh Explore server title'), findsOneWidget);
      expect(find.text('Following current title'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
