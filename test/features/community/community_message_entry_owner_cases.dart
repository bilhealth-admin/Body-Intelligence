part of 'community_chat_auth_session_test.dart';

class _EntryRepository extends _Repository {
  _EntryRepository(super.client);
  Completer<List<Map<String, dynamic>>>? inbox;
  int inboxLoads = 0, sentLoads = 0;
  bool failInbox = false, failSent = false, failSend = false;
  bool policyAccepted = true;
  final acceptances = <String>[];
  @override
  Future<List<Map<String, dynamic>>> loadInboxMessages() async {
    inboxLoads++;
    if (failInbox) throw StateError('inbox offline');
    return inbox?.future ??
        [
          _messageJson()..['profile'] = {'display_name': 'Private peer'},
        ];
  }

  @override
  Future<List<Map<String, dynamic>>> loadSentMessages() async {
    sentLoads++;
    if (failSent) throw StateError('sent offline');
    return [];
  }

  @override
  Future<void> sendMessage(String peer, String body) async {
    sends.add(body);
    if (failSend) throw StateError('send offline');
    await pendingSend?.future;
  }

  @override
  Stream<void> watchInboxChanges() => changes.stream;
  @override
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async => [
    {'user_id': _peer, 'display_name': 'Private peer'},
  ];
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => policyAccepted
      ? _acceptedPolicy()
      : CommunityPolicyState.fromServerSnapshot({
          'server_now': '2026-10-06T12:00:00Z',
          'status': 'acceptance_required',
          'version': 'test-policy-v1',
          'document_url': 'https://policy.example.invalid/community',
          'effective_at': '2026-10-01T00:00:00Z',
          'accepted': false,
        });
  @override
  Future<void> acceptContentPolicy(String version) async {
    acceptances.add(version);
    policyAccepted = true;
  }
}

void _messageEntryCases(
  _AuthFixture Function() fixture,
  void Function(_Repository) track,
) {
  for (final page in ['inbox', 'new']) {
    for (final aba in [false, true]) {
      _case(
        '$page entry retires private content on real ${aba ? 'A-B-A' : 'A-B'}',
        (tester) async {
          final auth = fixture();
          final repo = _EntryRepository(auth.client);
          track(repo);
          await tester.pumpWidget(
            MaterialApp(
              home: page == 'inbox'
                  ? CommunityMessagesPage(repository: repo)
                  : NewCommunityMessagePage(repository: repo),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Private peer'), findsOneWidget);
          if (page == 'new') {
            await tester.tap(find.text('Private peer'));
            await tester.pump();
            await tester.enterText(
              find.byKey(const Key('community-message-subject')),
              'Private subject',
            );
            await tester.enterText(
              find.byKey(const Key('community-message-body')),
              'Private body',
            );
          }
          if (aba) {
            await auth.roundTrip();
          } else {
            await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
          }
          await tester.pumpAndSettle();
          expect(find.text('Private peer'), findsNothing);
          expect(find.text('Private subject'), findsNothing);
          expect(find.text('Private body'), findsNothing);
          expect(repo.sends, isEmpty);
        },
      );
    }
  }
  _case('pending inbox cannot paint after queued owner replacement', (
    tester,
  ) async {
    final auth = fixture();
    final pending = Completer<List<Map<String, dynamic>>>();
    final repo = _EntryRepository(auth.client)..inbox = pending;
    track(repo);
    await tester.pumpWidget(
      MaterialApp(home: CommunityMessagesPage(repository: repo)),
    );
    await tester.pump();
    await auth.roundTrip();
    await tester.pump();
    pending.complete([
      _messageJson()..['profile'] = {'display_name': 'Private peer'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Private peer'), findsNothing);
    expect(repo.reads, isEmpty);
  });
  _case(
    'new message keeps subject and body when total envelope exceeds server limit',
    (tester) async {
      final repo = _EntryRepository(fixture().client);
      track(repo);
      await tester.pumpWidget(
        MaterialApp(home: NewCommunityMessagePage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private peer'));
      await tester.pump();
      final subject = find.byKey(const Key('community-message-subject'));
      final body = find.byKey(const Key('community-message-body'));
      await tester.enterText(subject, 'Subject');
      await tester.enterText(body, '😀' * 1990);
      await tester.tap(find.byKey(const Key('community-message-send')));
      await tester.pump();
      expect(repo.sends, isEmpty);
      expect(tester.widget<TextField>(subject).controller!.text, 'Subject');
      expect(tester.widget<TextField>(body).controller!.text, '😀' * 1990);
    },
  );
  _case('new message never clips a long subject or body', (tester) async {
    final repo = _EntryRepository(fixture().client);
    track(repo);
    await tester.pumpWidget(
      MaterialApp(home: NewCommunityMessagePage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private peer'));
    await tester.pump();
    final subject = find.byKey(const Key('community-message-subject'));
    final body = find.byKey(const Key('community-message-body'));
    await tester.enterText(subject, 'x' * 121);
    await tester.enterText(body, 'y' * 4201);
    expect(tester.widget<TextField>(subject).controller!.text, 'x' * 121);
    expect(tester.widget<TextField>(body).controller!.text, 'y' * 4201);
    await tester.tap(find.byKey(const Key('community-message-send')));
    await tester.pump();
    expect(repo.sends, isEmpty);
  });
}
