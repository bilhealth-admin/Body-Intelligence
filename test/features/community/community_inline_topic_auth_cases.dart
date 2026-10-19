part of 'community_composer_auth_session_test.dart';

class _InlineTopicAuthRepository extends _FeedComposerRepository {
  _InlineTopicAuthRepository(super.client);
  final pendingCategory = Completer<CommunityTopicPostBatch>();
  final reads = <String>[];

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [
    CommunityTopic(
      slug: 'nutrition',
      titleCopyKey: 'topic_title',
      descriptionCopyKey: 'topic_description',
      iconKey: 'nutrition',
      featured: false,
      followerCount: 0,
      postCount: 0,
      following: false,
    ),
  ];

  @override
  Future<CommunityTopicPostBatch> loadCommunityTopicPosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) {
    expect(slug, 'nutrition');
    reads.add(currentUserId);
    return pendingCategory.future;
  }
}

void _inlineTopicOwnerTests(_ComposerAuthFixture Function() readAuth) {
  for (final roundTrip in [false, true]) {
    _composerTest(
      'inline category rejects pending real ${roundTrip ? 'A B A' : 'A B'} response',
      (tester) async {
        final auth = readAuth();
        final repository = _InlineTopicAuthRepository(auth.client);
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: CommunityHubPage(
                repository: repository,
                entryWelcomeHandled: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('community-category-nutrition')));
        await tester.pump();
        expect(repository.reads, [_ownerA]);
        if (roundTrip) {
          await auth.roundTrip();
        } else {
          await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
        }
        // Resolve before a frame removes the old widget: the owner operation,
        // rather than disposal alone, must reject the queued old result.
        repository.pendingCategory.complete(
          CommunityTopicPostBatch(
            posts: [
              CommunityPost(
                id: _draftA,
                authorId: _ownerA,
                body: 'Retired account category content',
                createdAt: DateTime.utc(2026, 10, 19),
              ),
            ],
            hasMore: false,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Retired account category content'), findsNothing);
        expect(auth.client.auth.currentUser!.id, roundTrip ? _ownerA : _ownerB);
        expect(repository.reads, [_ownerA]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
