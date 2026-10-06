part of 'community_composer_auth_session_test.dart';

final _feedAcceptedPolicy = CommunityPolicyState.accepted(
  CommunityContentPolicy.fromJson({
    'version': 'community-policy-v1',
    'locale_code': 'en',
    'document_url': 'https://www.bilhealth.com/community-guidelines',
    'effective_at': '2026-09-08T00:00:00Z',
  }),
  acceptedVersion: 'community-policy-v1',
);

class _FeedComposerRepository extends _ComposerRepository {
  _FeedComposerRepository(super.client);

  Completer<CommunityPolicyState>? nextPolicy;
  int acceptedPolicyWrites = 0;

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    final pending = nextPolicy;
    nextPolicy = null;
    return pending == null ? _feedAcceptedPolicy : await pending.future;
  }

  @override
  Future<void> acceptContentPolicy(String version) async {
    acceptedPolicyWrites++;
  }

  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async => null;

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => const [];

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => const [];
}

void _feedComposerOwnerTests(_ComposerAuthFixture Function() readAuth) {
  for (final roundTrip in [false, true]) {
    _composerTest(
      'feed pending policy cannot reopen old draft after real ${roundTrip ? 'A B A' : 'A B'}',
      (tester) async {
        final auth = readAuth();
        final repository = _FeedComposerRepository(auth.client);
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
        final create = find.byKey(const Key('community-create-post'));
        await tester.tap(create);
        await tester.pumpAndSettle();
        await tester.enterText(_body, 'Only account A owns this unsaved draft');
        await tester.tap(find.byKey(const Key('community-post-editor-close')));
        await tester.pumpAndSettle();
        expect(_editor, findsNothing);

        final pending = Completer<CommunityPolicyState>();
        repository.nextPolicy = pending;
        await tester.tap(create);
        await tester.pump();
        expect(_editor, findsNothing);
        final delivered = <String?>[];
        final subscription = auth.client.auth.onAuthStateChange.listen(
          (state) => delivered.add(state.session?.user.id),
        );
        addTearDown(subscription.cancel);
        if (roundTrip) {
          await auth.roundTrip();
        } else {
          await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
        }
        // Resolve the old request before a frame can dispose a replaced feed.
        // Neither a transient B session nor a final B session may inherit A's
        // in-memory content through a newly constructed composer.
        pending.complete(_feedAcceptedPolicy);
        await tester.pumpAndSettle();
        expect(delivered, contains(_ownerB));
        expect(auth.client.auth.currentUser!.id, roundTrip ? _ownerA : _ownerB);
        expect(_editor, findsNothing);
        expect(repository.published, isEmpty);
        expect(repository.saved, isEmpty);
        expect(repository.profileReads, 0);
        expect(repository.acceptedPolicyWrites, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
