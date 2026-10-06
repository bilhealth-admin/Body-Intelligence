part of 'community_chat_auth_session_test.dart';

void _messageRetryCases(
  _AuthFixture Function() fixture,
  void Function(_Repository) track,
) {
  for (final page in ['chat', 'inbox', 'new']) {
    _case('$page cold root has a safe dashboard return', (tester) async {
      final repo = _EntryRepository(fixture().client);
      track(repo);
      final router = GoRouter(
        initialLocation: '/entry',
        routes: [
          GoRoute(
            path: '/entry',
            builder: (_, _) => switch (page) {
              'chat' => CommunityChatPage(
                userId: _peer,
                displayName: 'Peer',
                repository: repo,
              ),
              'inbox' => CommunityMessagesPage(repository: repo),
              _ => NewCommunityMessagePage(repository: repo),
            },
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const Scaffold(body: Text('Safe dashboard')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-safe-return')));
      await tester.pumpAndSettle();
      expect(find.text('Safe dashboard'), findsOneWidget);
    });
  }
  _case('both inbox errors are observed and each tab can explicitly retry', (
    tester,
  ) async {
    final repo = _EntryRepository(fixture().client)
      ..failInbox = true
      ..failSent = true;
    track(repo);
    await tester.pumpWidget(
      MaterialApp(home: CommunityMessagesPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    repo.failInbox = false;
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Private peer'), findsOneWidget);
    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    repo.failSent = false;
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();
    expect(repo.sentLoads, 2);
    expect(tester.takeException(), isNull);
  });
  _case(
    'failed new message keeps original subject body and recipient for one explicit retry',
    (tester) async {
      final repo = _EntryRepository(fixture().client)..failSend = true;
      track(repo);
      final router = GoRouter(
        initialLocation: '/new',
        routes: [
          GoRoute(
            path: '/new',
            builder: (_, _) => NewCommunityMessagePage(repository: repo),
          ),
          GoRoute(
            path: '/community/messages',
            builder: (_, _) => const Scaffold(body: Text('Returned inbox')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private peer'));
      await tester.pump();
      final subject = find.byKey(const Key('community-message-subject'));
      final body = find.byKey(const Key('community-message-body'));
      await tester.enterText(subject, 'Original subject');
      await tester.enterText(body, 'Original body 👩‍💻');
      await tester.tap(find.byKey(const Key('community-message-send')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(subject).controller!.text,
        'Original subject',
      );
      expect(
        tester.widget<TextField>(body).controller!.text,
        'Original body 👩‍💻',
      );
      expect(find.text('Private peer'), findsOneWidget);
      expect(repo.sends, [
        '[BIL-SUBJECT]Original subject\nOriginal body 👩‍💻',
      ]);
      repo.failSend = false;
      await tester.tap(find.byKey(const Key('community-message-send')));
      await tester.pumpAndSettle();
      expect(find.text('Returned inbox'), findsOneWidget);
      expect(repo.sends, [repo.sends.first, repo.sends.first]);
    },
  );
  for (final page in ['inbox', 'new']) {
    _case('$page repository replacement rejects old private cached state', (
      tester,
    ) async {
      final old = _EntryRepository(fixture().client);
      final next = _EntryRepository(fixture().client);
      track(old);
      track(next);
      Widget app(_EntryRepository repo) => MaterialApp(
        home: page == 'inbox'
            ? CommunityMessagesPage(
                key: const ValueKey('page'),
                repository: repo,
              )
            : NewCommunityMessagePage(
                key: const ValueKey('page'),
                repository: repo,
              ),
      );
      await tester.pumpWidget(app(old));
      await tester.pumpAndSettle();
      if (page == 'new') {
        await tester.tap(find.text('Private peer'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('community-message-body')),
          'Old draft',
        );
      }
      await tester.pumpWidget(app(next));
      await tester.pumpAndSettle();
      expect(find.text('Old draft'), findsNothing);
      expect(next.inboxLoads, page == 'inbox' ? 1 : 0);
      expect(old.sends, isEmpty);
      expect(next.sends, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  _case('an open policy sheet cannot accept for a retired message owner', (
    tester,
  ) async {
    final auth = fixture();
    final repo = _EntryRepository(auth.client)..policyAccepted = false;
    track(repo);
    await tester.pumpWidget(
      MaterialApp(home: NewCommunityMessagePage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review policy'));
    await tester.pumpAndSettle();
    final checkbox = find.byKey(const Key('confirm-community-policy'));
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
    final button = find.byKey(const Key('accept-community-policy'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final staleAccept = tester.widget<FilledButton>(button).onPressed!;
    await auth.roundTrip();
    staleAccept();
    await tester.pumpAndSettle();
    expect(repo.acceptances, isEmpty);
    expect(find.byKey(const Key('accept-community-policy')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'inbox owner switch after message read prevents the follow-up public-profile query',
    () async {
      final auth = fixture();
      final started = Completer<http.Request>();
      final pending = Completer<http.Response>();
      final paths = <String>[];
      auth.dataRequest = (request) async {
        paths.add(request.url.path);
        started.complete(request);
        return pending.future;
      };
      final future = CommunityRepository(auth.client).loadInboxMessages();
      final assertion = expectLater(
        future,
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      final request = await started.future;
      await auth.roundTrip();
      await Future<void>.delayed(Duration.zero);
      pending.complete(_jsonResponse(request, [_messageJson()]));
      await assertion;
      expect(paths, ['/rest/v1/bil_messages']);
    },
  );
}
