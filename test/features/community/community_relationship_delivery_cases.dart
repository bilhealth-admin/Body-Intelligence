part of 'community_chat_auth_session_test.dart';

Widget _relationshipApp({Widget? home, GoRouter? router}) {
  const delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  return router == null
      ? MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: delegates,
          home: home,
        )
      : MaterialApp.router(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: delegates,
          routerConfig: router,
        );
}

class _RelationsRepository extends _EntryRepository {
  _RelationsRepository(super.client);
  List<Map<String, dynamic>> relations = [];
  int relationshipLoads = 0, cancellations = 0;
  int searches = 0;
  bool peerHidden = false;
  bool failRelationshipLoad = false;
  Completer<List<Map<String, dynamic>>>? relationshipResponse;
  Completer<CommunityFriendRequestStatus>? friendResponse;
  @override
  Stream<void> watchConnectionChanges() => changes.stream;
  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async {
    relationshipLoads++;
    if (failRelationshipLoad) throw StateError('fixture_connection_offline');
    if (relationshipResponse != null) return relationshipResponse!.future;
    return List.of(relations);
  }

  @override
  Future<void> cancelFriendRequest(String id) async {
    cancellations++;
    relations.removeWhere((row) => row['id'] == id);
  }

  @override
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    searches++;
    return [
      if (!peerHidden)
        {
          'user_id': _peer,
          'display_name': 'Private peer',
          'handle': 'private_peer',
        },
    ];
  }

  @override
  Future<CommunityFriendRequestStatus> requestFriend(String id) async {
    if (friendResponse != null) return friendResponse!.future;
    // Match the real pending receipt: its relationship exists in storage.
    if (!relations.any((row) => row['other_user_id'] == id)) {
      relations.add(_friendRow(incoming: false));
    }
    return CommunityFriendRequestStatus.pending;
  }
}

class _PreviewRepository extends _EntryRepository {
  _PreviewRepository(super.client);
  bool failPage = false;
  final cursors = <String>[];
  @override
  Future<List<Map<String, dynamic>>> loadInboxMessages() async => List.generate(
    100,
    (index) => {
      ..._messageJson(
        id: '77777777-7777-4777-8777-${index.toString().padLeft(12, '0')}',
      ),
      'created_at': DateTime.utc(
        2026,
        10,
        6,
        12,
      ).subtract(Duration(seconds: index)).toIso8601String(),
      'profile': {'display_name': 'Recent peer'},
    },
  );
  @override
  Future<List<Map<String, dynamic>>> loadOlderMessagePreviews({
    required bool incoming,
    required DateTime before,
    required String beforeId,
  }) async {
    expect(incoming, isTrue);
    cursors.add(beforeId);
    if (failPage) throw StateError('older page offline');
    return [
      {
        ..._messageJson(id: _secondId, peer: _other),
        'created_at': before
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
        'profile': {'display_name': 'Older unread peer'},
      },
    ];
  }
}

class _TerminalDeliveryRepository extends _EntryRepository {
  _TerminalDeliveryRepository(super.client);
  bool removed = true;
  @override
  Future<void> sendMessageOperation(
    String recipientId,
    String body, {
    required String requestId,
  }) async {
    operationRequests.add(requestId);
    if (removed) throw const CommunityMessageDeliveryRemoved();
    await sendMessage(recipientId, body);
  }
}

class _WithdrawnMessagePolicyRepository extends _PolicyRepository {
  _WithdrawnMessagePolicyRepository(super.client);
  int policyReads = 0;
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    policyReads++;
    return CommunityPolicyState.fromServerSnapshot({
      'server_now': '2026-10-13T06:00:00Z',
      'status': 'acceptance_required',
      'version': 'test-policy-v2',
      'document_url': 'https://policy.example.invalid/community',
      'effective_at': '2026-10-12T00:00:00Z',
      'accepted': false,
    });
  }
}

http.Response _deliveryResponse(http.Request request, Object? body) =>
    http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );

Map<String, dynamic> _friendRow({bool incoming = true}) => {
  'id': _messageId,
  'requester_id': incoming ? _peer : _ownerA,
  'addressee_id': incoming ? _ownerA : _peer,
  'other_user_id': _peer,
  'status': 'pending',
  'profile': {'display_name': 'Private peer'},
};

Map<String, dynamic> _deliveryReceipt(
  String requestId,
  String body, {
  String messageId = _messageId,
  String owner = _ownerA,
}) => {
  'request_id': requestId,
  'owner_id': owner,
  'recipient_id': _peer,
  'message_id': messageId,
  'body': body,
  'status': 'delivered',
  'delivered_at': '2026-10-13T06:00:00Z',
};

void _relationshipDeliveryCases(
  _AuthFixture Function() fixture,
  void Function(_Repository) track,
) {
  _case('outgoing pending request has a real cancel action and reloads', (
    tester,
  ) async {
    final repo = _RelationsRepository(fixture().client)
      ..relations = [_friendRow(incoming: false)];
    track(repo);
    await tester.pumpWidget(
      _relationshipApp(home: CommunityConnectionsPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancel request'));
    await tester.pumpAndSettle();
    expect(repo.cancellations, 1);
    expect(repo.relations, isEmpty);
    expect(find.text('Private peer'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  _case(
    'People returning from a blocked profile removes the stale search row',
    (tester) async {
      final repo = _RelationsRepository(fixture().client);
      track(repo);
      final router = GoRouter(
        initialLocation: '/people',
        routes: [
          GoRoute(
            path: '/people',
            builder: (_, _) => CommunityPeoplePage(repository: repo),
          ),
          GoRoute(
            path: '/community/profile/:id',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () {
                  repo.peerHidden = true;
                  context.pop();
                },
                child: const Text('Block fixture peer'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_relationshipApp(router: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private peer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block fixture peer'));
      await tester.pumpAndSettle();
      expect(find.text('Private peer'), findsNothing);
      expect(find.text('No people found.'), findsOneWidget);
      expect(repo.searches, 2);
      expect(tester.takeException(), isNull);
    },
  );
  _case('People profile return preserves a still pending request', (
    tester,
  ) async {
    final repo = _RelationsRepository(fixture().client);
    track(repo);
    final router = GoRouter(
      initialLocation: '/people',
      routes: [
        GoRoute(
          path: '/people',
          builder: (_, _) => CommunityPeoplePage(repository: repo),
        ),
        GoRoute(
          path: '/community/profile/:id',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Return without changing relationship'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_relationshipApp(router: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send request'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pending'), findsOneWidget);
    await tester.tap(find.text('Private peer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return without changing relationship'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pending'), findsOneWidget);
    expect(find.byTooltip('Send request'), findsNothing);
    expect(repo.searches, 2);
  });
  _case('People profile cancellation refreshes the pending search action', (
    tester,
  ) async {
    final repo = _RelationsRepository(fixture().client);
    track(repo);
    final router = GoRouter(
      initialLocation: '/people',
      routes: [
        GoRoute(
          path: '/people',
          builder: (_, _) => CommunityPeoplePage(repository: repo),
        ),
        GoRoute(
          path: '/community/profile/:id',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await repo.cancelFriendRequest(_messageId);
                if (context.mounted) context.pop();
              },
              child: const Text('Cancel fixture request and return'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_relationshipApp(router: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send request'));
    await tester.pumpAndSettle();
    repo.relations = [_friendRow(incoming: false)];
    expect(find.byTooltip('Pending'), findsOneWidget);
    await tester.tap(find.text('Private peer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel fixture request and return'));
    await tester.pumpAndSettle();
    expect(repo.cancellations, 1);
    expect(repo.relations, isEmpty);
    expect(find.byTooltip('Pending'), findsNothing);
    expect(find.byTooltip('Send request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final ownerChanges in [false, true]) {
    _case(
      'People profile refresh ${ownerChanges ? 'retires a held result after A B A' : 'failure retains the confirmed pending state'}',
      (tester) async {
        final auth = fixture();
        final repo = _RelationsRepository(auth.client);
        track(repo);
        final held = Completer<List<Map<String, dynamic>>>();
        final router = GoRouter(
          initialLocation: '/people',
          routes: [
            GoRoute(
              path: '/people',
              builder: (_, _) => CommunityPeoplePage(repository: repo),
            ),
            GoRoute(
              path: '/community/profile/:id',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    if (ownerChanges) {
                      repo.relationshipResponse = held;
                    } else {
                      repo.failRelationshipLoad = true;
                    }
                    context.pop();
                  },
                  child: const Text('Return to relationship refresh'),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        addTearDown(() {
          if (!held.isCompleted) held.complete([]);
        });
        await tester.pumpWidget(_relationshipApp(router: router));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Send request'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Private peer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Return to relationship refresh'));
        if (ownerChanges) {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(repo.relationshipLoads, 1);
          await auth.roundTrip();
          held.complete([_friendRow(incoming: false)]);
          await tester.pumpAndSettle();
          expect(find.text('Private peer'), findsNothing);
          expect(find.byTooltip('Send request'), findsNothing);
        } else {
          await tester.pumpAndSettle();
          expect(find.byTooltip('Pending'), findsOneWidget);
          expect(find.byTooltip('Send request'), findsNothing);
          expect(
            find.text('Could not refresh the connection. Try again.'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  _case(
    'empty connections can pull refresh and receive the first live request',
    (tester) async {
      final repo = _RelationsRepository(fixture().client);
      track(repo);
      await tester.pumpWidget(
        _relationshipApp(home: CommunityConnectionsPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsOneWidget);
      repo.relations = [_friendRow()];
      repo.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Private peer'), findsOneWidget);
      expect(find.byTooltip('Accept'), findsOneWidget);
      expect(repo.relationshipLoads, greaterThan(1));
    },
  );
  _case('connections returning from People reloads its pending rows', (
    tester,
  ) async {
    final repo = _RelationsRepository(fixture().client);
    track(repo);
    final router = GoRouter(
      initialLocation: '/connections',
      routes: [
        GoRoute(
          path: '/connections',
          builder: (_, _) => CommunityConnectionsPage(repository: repo),
        ),
        GoRoute(
          path: '/community/people',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () {
                repo.relations = [_friendRow(incoming: false)];
                context.pop();
              },
              child: const Text('Send fixture request'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_relationshipApp(router: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Find people'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send fixture request'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cancel request'), findsOneWidget);
    expect(find.text('Private peer'), findsOneWidget);
  });
  for (final page in ['connections', 'people']) {
    _case('$page retires cached relationships after actual queued A B A', (
      tester,
    ) async {
      final auth = fixture();
      final repo = _RelationsRepository(auth.client)
        ..relations = [_friendRow()];
      track(repo);
      await tester.pumpWidget(
        _relationshipApp(
          home: page == 'connections'
              ? CommunityConnectionsPage(repository: repo)
              : CommunityPeoplePage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      if (page == 'connections') {
        await tester.tap(find.text('Requests'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Private peer'), findsOneWidget);
      await auth.roundTrip();
      await tester.pumpAndSettle();
      expect(find.text('Private peer'), findsNothing);
      expect(find.byTooltip('Accept'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  _case(
    'failed chat send reuses request UUID and success permits a new identical message',
    (tester) async {
      final repo = _EntryRepository(fixture().client)..failSend = true;
      track(repo);
      await _mount(tester, repo);
      await tester.enterText(_composer, 'Same deliberate body');
      await tester.pump();
      await tester.tap(_send);
      await tester.pumpAndSettle();
      repo.failSend = false;
      if (find.byType(SnackBar).evaluate().isNotEmpty) {
        await tester.drag(find.byType(SnackBar), const Offset(0, 100));
        await tester.pumpAndSettle();
      }
      await tester.tap(_send);
      await tester.pumpAndSettle();
      expect(repo.operationRequests, hasLength(2));
      expect(repo.operationRequests[0], repo.operationRequests[1]);
      await tester.enterText(_composer, 'Same deliberate body');
      await tester.pump();
      await tester.tap(_send);
      await tester.pumpAndSettle();
      expect(repo.operationRequests[2], isNot(repo.operationRequests[0]));
    },
  );
  for (final page in ['chat', 'new']) {
    _case(
      '$page removed delivery preserves draft and needs explicit new-message confirmation',
      (tester) async {
        final repo = _TerminalDeliveryRepository(fixture().client);
        track(repo);
        if (page == 'chat') {
          await _mount(tester, repo);
          await tester.enterText(_composer, 'Kept removed draft');
          await tester.pump();
        } else {
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => NewCommunityMessagePage(repository: repo),
              ),
              GoRoute(
                path: '/community/messages',
                builder: (_, _) =>
                    const Scaffold(body: Text('Messages destination')),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(_relationshipApp(router: router));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Private peer'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('community-message-body')),
            'Kept removed draft',
          );
          await tester.pump();
        }
        final send = page == 'chat'
            ? _send
            : find.byKey(const Key('community-message-send'));
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(find.text('Kept removed draft'), findsOneWidget);
        expect(
          find.text(
            'This message was previously delivered and then removed. Your text is kept; no new message was sent.',
          ),
          findsOneWidget,
        );
        expect(repo.operationRequests, hasLength(1));
        expect(repo.sends, isEmpty);
        final oldRequest = repo.operationRequests.single;
        if (find.byType(SnackBar).evaluate().isNotEmpty) {
          await tester.drag(find.byType(SnackBar), const Offset(0, 100));
          await tester.pumpAndSettle();
        }
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('community-message-replacement-confirmation')),
          findsOneWidget,
        );
        expect(repo.operationRequests, [oldRequest]);
        await tester.tap(
          find.byKey(const Key('community-message-replacement-cancel')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Kept removed draft'), findsOneWidget);
        expect(repo.operationRequests, [oldRequest]);
        repo.removed = false;
        await tester.tap(send);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('community-message-replacement-send')),
        );
        await tester.pumpAndSettle();
        expect(repo.operationRequests, hasLength(2));
        expect(repo.operationRequests.last, isNot(oldRequest));
        expect(repo.sends, hasLength(1));
        if (page == 'chat') {
          expect(find.text('Kept removed draft'), findsNothing);
        } else {
          expect(find.text('Messages destination'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  _case('Inbox discovers an older peer beyond one hundred recent messages', (
    tester,
  ) async {
    final repo = _PreviewRepository(fixture().client);
    track(repo);
    await tester.pumpWidget(
      _relationshipApp(home: CommunityMessagesPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recent peer'), findsOneWidget);
    expect(find.text('Older unread peer'), findsNothing);
    await tester.tap(find.byKey(const Key('community-inbox-load-older')));
    await tester.pumpAndSettle();
    expect(find.text('Older unread peer'), findsOneWidget);
    expect(find.text('Recent peer'), findsOneWidget);
    expect(repo.cursors, ['77777777-7777-4777-8777-000000000099']);
    expect(find.byKey(const Key('community-inbox-load-older')), findsNothing);
  });
  _case('failed older Inbox page retains rows and retries the same cursor', (
    tester,
  ) async {
    final repo = _PreviewRepository(fixture().client)..failPage = true;
    track(repo);
    await tester.pumpWidget(
      _relationshipApp(home: CommunityMessagesPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    final older = find.byKey(const Key('community-inbox-load-older'));
    await tester.tap(older);
    await tester.pumpAndSettle();
    expect(find.text('Recent peer'), findsOneWidget);
    expect(find.text('Older unread peer'), findsNothing);
    repo.failPage = false;
    await tester.tap(older);
    await tester.pumpAndSettle();
    expect(find.text('Older unread peer'), findsOneWidget);
    expect(repo.cursors, hasLength(2));
    expect(repo.cursors.first, repo.cursors.last);
  });
  test(
    'v2 missing server reports unavailable without the legacy POST',
    () async {
      final auth = fixture();
      final paths = <String>[];
      auth.dataRequest = (request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode({'code': 'PGRST202', 'message': 'function missing'}),
          404,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      };
      await expectLater(
        _PolicyRepository(
          auth.client,
        ).sendMessageOperation(_peer, 'Body', requestId: _messageId),
        throwsA(isA<CommunityMessageDeliveryUnavailable>()),
      );
      expect(paths, ['/rest/v1/rpc/bil_get_community_message_delivery_v2']);
    },
  );
  test(
    'v2 reconciliation requires the same owner recipient body and stored message identity',
    () async {
      final auth = fixture();
      var foreignReadback = true;
      var receiptReads = 0;
      auth.dataRequest = (request) async {
        final reading = request.url.path.endsWith(
          'bil_get_community_message_delivery_v2',
        );
        if (reading && receiptReads++ == 0) {
          return _deliveryResponse(request, null);
        }
        return _jsonResponse(
          request,
          _deliveryReceipt(
            _messageId,
            'Body',
            owner: reading && foreignReadback ? _ownerB : _ownerA,
          ),
        );
      };
      final repo = _PolicyRepository(auth.client);
      await expectLater(
        repo.sendMessageOperation(_peer, 'Body', requestId: _messageId),
        throwsFormatException,
      );
      foreignReadback = false;
      await repo.sendMessageOperation(_peer, 'Body', requestId: _messageId);
    },
  );
  test(
    'v2 committed-response loss retries one request and preserves a second identical intent',
    () async {
      final auth = fixture();
      final stored = <String, Map<String, dynamic>>{};
      var loseResponse = true;
      auth.dataRequest = (request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final key = body['p_request_id'] as String;
        if (request.url.path.endsWith('bil_send_community_message_v2')) {
          stored.putIfAbsent(key, () => _deliveryReceipt(key, 'Body'));
          if (loseResponse) {
            loseResponse = false;
            return http.Response('temporary loss', 504, request: request);
          }
        }
        return _deliveryResponse(request, stored[key]);
      };
      final repo = _PolicyRepository(auth.client);
      await expectLater(
        repo.sendMessageOperation(_peer, 'Body', requestId: _messageId),
        throwsA(isA<Exception>()),
      );
      await repo.sendMessageOperation(_peer, 'Body', requestId: _messageId);
      expect(stored, hasLength(1));
      await repo.sendMessageOperation(_peer, 'Body', requestId: _secondId);
      expect(stored, hasLength(2));
    },
  );
  test(
    'v2 owner change after primary reply cannot start receipt readback',
    () async {
      final auth = fixture();
      final start = Completer<http.Request>(),
          pending = Completer<http.Response>();
      final paths = <String>[];
      auth.dataRequest = (request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith(
          'bil_get_community_message_delivery_v2',
        )) {
          return _deliveryResponse(request, null);
        }
        start.complete(request);
        return pending.future;
      };
      final future = _PolicyRepository(
        auth.client,
      ).sendMessageOperation(_peer, 'Body', requestId: _messageId);
      final assertion = expectLater(
        future,
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      final request = await start.future;
      await auth.roundTrip();
      await Future<void>.delayed(Duration.zero);
      pending.complete(
        _jsonResponse(request, _deliveryReceipt(_messageId, 'Body')),
      );
      await assertion;
      expect(paths, [
        '/rest/v1/rpc/bil_get_community_message_delivery_v2',
        '/rest/v1/rpc/bil_send_community_message_v2',
      ]);
    },
  );
  test(
    'v2 committed receipt reconciliation bypasses new-write consent only',
    () async {
      final auth = fixture();
      final paths = <String>[];
      auth.dataRequest = (request) async {
        paths.add(request.url.path);
        return _jsonResponse(request, _deliveryReceipt(_messageId, 'Body'));
      };
      final repo = _WithdrawnMessagePolicyRepository(auth.client);
      await repo.sendMessageOperation(_peer, 'Body', requestId: _messageId);
      expect(repo.policyReads, 0);
      expect(paths, [
        '/rest/v1/rpc/bil_get_community_message_delivery_v2',
        '/rest/v1/rpc/bil_send_community_message_v2',
        '/rest/v1/rpc/bil_get_community_message_delivery_v2',
      ]);
      paths.clear();
      auth.dataRequest = (request) async {
        paths.add(request.url.path);
        return _deliveryResponse(request, null);
      };
      await expectLater(
        repo.sendMessageOperation(_peer, 'Body', requestId: _secondId),
        throwsA(isA<CommunityPolicyAccessException>()),
      );
      expect(repo.policyReads, 1);
      expect(paths, ['/rest/v1/rpc/bil_get_community_message_delivery_v2']);
    },
  );
  for (final physicalDelete in [false, true]) {
    test(
      'v2 ${physicalDelete ? 'physically deleted' : 'removed'} receipt is terminal after owned readback',
      () async {
        final auth = fixture();
        final paths = <String>[];
        auth.dataRequest = (request) async {
          paths.add(request.url.path);
          return _jsonResponse(request, {
            ..._deliveryReceipt(_messageId, 'Body'),
            'status': 'removed',
            'body': null,
            'message_id': physicalDelete ? null : _messageId,
          });
        };
        final repo = _WithdrawnMessagePolicyRepository(auth.client);
        await expectLater(
          repo.sendMessageOperation(_peer, 'Body', requestId: _messageId),
          throwsA(isA<CommunityMessageDeliveryRemoved>()),
        );
        expect(repo.policyReads, 0);
        expect(paths, [
          '/rest/v1/rpc/bil_get_community_message_delivery_v2',
          '/rest/v1/rpc/bil_send_community_message_v2',
          '/rest/v1/rpc/bil_get_community_message_delivery_v2',
        ]);
      },
    );
  }
  test(
    'v2 removed receipt cannot use another owner or an unbound recipient',
    () async {
      final auth = fixture();
      final paths = <String>[];
      for (final mismatch in ['owner_id', 'recipient_id']) {
        auth.dataRequest = (request) async {
          paths.add(request.url.path);
          return _jsonResponse(request, {
            ..._deliveryReceipt(_messageId, 'Body'),
            'status': 'removed',
            'body': null,
            mismatch: _ownerB,
          });
        };
        await expectLater(
          _PolicyRepository(
            auth.client,
          ).sendMessageOperation(_peer, 'Body', requestId: _messageId),
          throwsFormatException,
        );
      }
      expect(paths, [
        '/rest/v1/rpc/bil_get_community_message_delivery_v2',
        '/rest/v1/rpc/bil_get_community_message_delivery_v2',
      ]);
    },
  );
  test(
    'v2 prior receipt identity cannot be replaced by a different delivered message',
    () async {
      final auth = fixture();
      var reads = 0;
      auth.dataRequest = (request) async {
        final prior =
            request.url.path.endsWith(
              'bil_get_community_message_delivery_v2',
            ) &&
            reads++ == 0;
        return _jsonResponse(
          request,
          _deliveryReceipt(
            _messageId,
            'Body',
            messageId: prior ? _messageId : _secondId,
          ),
        );
      };
      await expectLater(
        _PolicyRepository(
          auth.client,
        ).sendMessageOperation(_peer, 'Body', requestId: _messageId),
        throwsFormatException,
      );
    },
  );
  test(
    'v2 a deletion between verified primary reply and readback is terminal',
    () async {
      final auth = fixture();
      var reads = 0;
      auth.dataRequest = (request) async {
        if (request.url.path.endsWith(
          'bil_get_community_message_delivery_v2',
        )) {
          if (reads++ == 0) return _deliveryResponse(request, null);
          return _jsonResponse(request, {
            ..._deliveryReceipt(_messageId, 'Body'),
            'status': 'removed',
            'body': null,
            'message_id': null,
          });
        }
        return _jsonResponse(request, _deliveryReceipt(_messageId, 'Body'));
      };
      await expectLater(
        _PolicyRepository(
          auth.client,
        ).sendMessageOperation(_peer, 'Body', requestId: _messageId),
        throwsA(isA<CommunityMessageDeliveryRemoved>()),
      );
    },
  );
  test(
    'v2 removed prior receipt still requires server payload binding before terminal display',
    () async {
      final auth = fixture();
      auth.dataRequest = (request) async {
        if (request.url.path.endsWith('bil_send_community_message_v2')) {
          return http.Response(
            jsonEncode({
              'code': '22023',
              'message': 'message_request_conflict',
            }),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return _jsonResponse(request, {
          ..._deliveryReceipt(_messageId, 'Body'),
          'status': 'removed',
          'body': null,
        });
      };
      await expectLater(
        _PolicyRepository(
          auth.client,
        ).sendMessageOperation(_peer, 'Different body', requestId: _messageId),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
  test(
    'request cancellation includes requester pending guard and verifies absence',
    () async {
      final auth = fixture();
      final requests = <http.Request>[];
      auth.dataRequest = (request) async {
        requests.add(request);
        return _jsonResponse(request, []);
      };
      await CommunityRepository(auth.client).cancelFriendRequest(_messageId);
      expect(requests.map((request) => request.method), ['DELETE', 'GET']);
      expect(requests.first.url.queryParameters['requester_id'], 'eq.$_ownerA');
      expect(requests.first.url.queryParameters['status'], 'eq.pending');
      expect(requests.last.url.queryParameters['requester_id'], 'eq.$_ownerA');
    },
  );
  test(
    'request cancellation does not erase an acceptance that won the race',
    () async {
      final auth = fixture();
      auth.dataRequest = (request) async => _jsonResponse(
        request,
        request.method == 'GET'
            ? [
                {'id': _messageId, 'status': 'accepted'},
              ]
            : [],
      );
      await expectLater(
        CommunityRepository(auth.client).cancelFriendRequest(_messageId),
        throwsStateError,
      );
    },
  );
  test(
    'older preview page uses owner direction and tied time UUID cursor',
    () async {
      final auth = fixture();
      late Uri uri;
      auth.dataRequest = (request) async {
        if (request.url.path.endsWith('bil_messages')) {
          uri = request.url;
          return _jsonResponse(request, [_messageJson()]);
        }
        return _jsonResponse(request, []);
      };
      await CommunityRepository(auth.client).loadOlderMessagePreviews(
        incoming: true,
        before: DateTime.utc(2026, 10, 6, 12),
        beforeId: _secondId,
      );
      expect(uri.queryParameters['recipient_id'], 'eq.$_ownerA');
      expect(uri.queryParameters['limit'], '100');
      expect(
        uri.queryParameters['order'],
        'created_at.desc.nullslast,id.desc.nullslast',
      );
      expect(uri.queryParameters['or'], contains('id.lt.$_secondId'));
    },
  );
}
