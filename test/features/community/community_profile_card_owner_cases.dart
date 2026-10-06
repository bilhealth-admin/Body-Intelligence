part of 'community_profile_auth_session_test.dart';

typedef _ProfileSelection = ({_ProfileRepository repository, String target});

Future<ValueNotifier<_ProfileSelection>> _mountCardProfile(
  WidgetTester tester,
  _ProfileRepository repository, {
  String target = _ownerA,
}) async {
  final selection = ValueNotifier<_ProfileSelection>((
    repository: repository,
    target: target,
  ));
  addTearDown(selection.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: ValueListenableBuilder<_ProfileSelection>(
        valueListenable: selection,
        builder: (_, selected, _) => CommunityMemberProfilePage(
          userId: selected.target,
          repository: selected.repository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byTooltip('List view').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('List view'));
    await tester.pumpAndSettle();
  }
  expect(find.byTooltip('Grid view'), findsOneWidget);
  return selection;
}

void _cardOwnerTests(
  _ProfileAuthFixture Function() authFixture,
  _ProfileRepository Function() repositoryFixture,
) {
  for (final replacement in ['target', 'repository']) {
    for (final action in ['like', 'save', 'detail']) {
      _profileTest(
        '$action crosses no old transport after $replacement replacement',
        (tester) async {
          final auth = authFixture();
          final repository = repositoryFixture();
          final selection = await _mountCardProfile(tester, repository);
          final pending = Completer<void>();
          switch (action) {
            case 'like':
              repository.pendingLike = pending;
            case 'save':
              repository.pendingSave = pending;
            case 'detail':
              repository.pendingStats = pending;
          }
          final suffix = action == 'detail' ? 'comments' : action;
          await _tap(
            tester,
            find.byKey(Key('community-post-$suffix-$_postId')),
          );
          expect(
            repository.count(
              action == 'detail' ? 'stats-start' : '$action-start',
            ),
            1,
          );
          final nextRepository = replacement == 'repository'
              ? _ProfileRepository(auth.client, prefix: 'Replacement ')
              : repository;
          selection.value = (
            repository: nextRepository,
            target: replacement == 'target' ? _member : _ownerA,
          );
          await tester.pump();
          expect(auth.client.auth.currentUser!.id, _ownerA);
          expect(
            nextRepository.count('profile'),
            replacement == 'target' ? 2 : 1,
          );
          pending.complete();
          await tester.pumpAndSettle();
          expect(auth.dataRequests, isEmpty);
          expect(tester.takeException(), isNull);
          if (action == 'detail') {
            expect(
              find.byKey(const Key('community-post-detail-list')),
              findsNothing,
            );
            expect(
              find.byKey(const Key('community-post-detail-retry')),
              findsNothing,
            );
          }
        },
      );
    }
    for (final action in ['friend', 'poll']) {
      _profileTest(
        'nested $action has no old transport after $replacement replacement',
        (tester) async {
          final auth = authFixture();
          final repository = repositoryFixture();
          repository.includePoll = action == 'poll';
          repository.useSdkFriend = action == 'friend';
          final selection = await _mountCardProfile(
            tester,
            repository,
            target: _member,
          );
          final pending = Completer<void>();
          if (action == 'friend') {
            repository.pendingFriend = pending;
          } else {
            repository.pendingVote = pending;
          }
          await _tap(
            tester,
            find.byKey(
              Key(
                action == 'friend'
                    ? 'community-post-add-friend-$_postId'
                    : 'community-poll-option-$_option',
              ),
            ),
          );
          expect(
            repository.count(action == 'friend' ? 'friend' : 'vote-start'),
            1,
          );
          selection.value = (
            repository: replacement == 'repository'
                ? _ProfileRepository(auth.client, prefix: 'Replacement ')
                : repository,
            target: replacement == 'target' ? _ownerA : _member,
          );
          await tester.pump();
          pending.complete();
          await tester.pumpAndSettle();
          expect(auth.dataRequests, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  _profileTest('valid profile reaction and save use actual SDK readback', (
    tester,
  ) async {
    final auth = authFixture();
    final repository = repositoryFixture();
    await _mountCardProfile(tester, repository);
    await _tap(tester, find.byKey(const Key('community-post-like-$_postId')));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('community-post-save-$_postId')));
    await tester.pumpAndSettle();
    expect(auth.dataRequests, ['bil_social_like_v2', 'bil_social_save_v2']);
    expect(find.byTooltip('Remove from saved'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('community-post-like-$_postId')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  _profileTest(
    'detail follow does not begin a late profile read after replacement',
    (tester) async {
      final auth = authFixture();
      final repository = repositoryFixture();
      final selection = await _mountCardProfile(
        tester,
        repository,
        target: _member,
      );
      await _tap(
        tester,
        find.byKey(const Key('community-post-comments-$_postId')),
      );
      await tester.pumpAndSettle();
      final readsBeforeFollow = repository.count('profile');
      final pending = Completer<void>();
      repository.pendingFollow = pending;
      await _tap(tester, find.byKey(const Key('community-post-detail-follow')));
      selection.value = (repository: repository, target: _ownerA);
      await tester.pump();
      expect(repository.count('profile'), readsBeforeFollow + 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(repository.count('profile'), readsBeforeFollow + 1);
      expect(auth.dataRequests, ['bil_social_stats_v2']);
    },
  );

  _profileTest(
    'connections follow awaits authoritative list before closing its scope',
    (tester) async {
      final repository = repositoryFixture();
      await _mount(tester, repository);
      await _tap(tester, find.text('Followers').first);
      await tester.pumpAndSettle();
      final pending = Completer<List<CommunityProfileConnection>>();
      repository.pendingConnections = pending;
      await _tap(
        tester,
        find.byKey(const Key('community-connection-follow-$_connection')),
      );
      expect(repository.count('connections'), 2);
      pending.complete([
        CommunityProfileConnection(
          userId: _connection,
          displayName: 'Authoritative follow readback',
          relationship: CommunityRelationshipStatus.none,
          connectedAt: DateTime.utc(2026, 10, 1),
          viewerFollows: true,
          allowFollows: true,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Authoritative follow readback'), findsOneWidget);
      expect(find.text('This list is unavailable right now.'), findsNothing);
      expect(repository.follows, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
