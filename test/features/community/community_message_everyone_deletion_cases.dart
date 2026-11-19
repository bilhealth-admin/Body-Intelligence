part of 'community_chat_auth_session_test.dart';

CommunityMessage _everyoneRow({bool incoming = false}) => CommunityMessage(
  id: _messageId,
  senderId: incoming ? _peer : _ownerA,
  recipientId: incoming ? _ownerA : _peer,
  body: 'Owned everyone fixture',
  createdAt: DateTime.utc(2026, 11, 19),
);

class _EveryoneDeleteServer {
  _EveryoneDeleteServer(this.auth, this.repo, this.row) {
    auth.dataRequest = request;
  }
  final _AuthFixture auth;
  final _Repository repo;
  final CommunityMessage row;
  final order = <String>[];
  int reads = 0, deletes = 0;
  bool erased = false,
      hiddenBefore = false,
      noEffect = false,
      failRpc = false,
      wrongIdentity = false;
  Completer<void>? holdPre, holdRpc;
  Future<http.Response> request(http.Request request) async {
    Object? body;
    if (request.method == 'GET' &&
        request.url.path == '/rest/v1/bil_messages') {
      reads++;
      order.add('read');
      expect(request.url.queryParameters['id'], 'eq.${row.id}');
      expect(
        request.url.queryParameters['select'],
        'id,sender_id,recipient_id',
      );
      if (reads == 1) await holdPre?.future;
      body = [
        if (!erased && !hiddenBefore)
          {
            'id': row.id,
            'sender_id': wrongIdentity ? _other : row.senderId,
            'recipient_id': row.recipientId,
          },
      ];
    } else if (request.method == 'POST' &&
        request.url.path == '/rest/v1/rpc/bil_delete_message_for_everyone_v1') {
      deletes++;
      order.add('everyone');
      expect(jsonDecode(request.body), {'p_message_id': row.id});
      await holdRpc?.future;
      if (failRpc) {
        return http.Response(
          jsonEncode({'code': 'PGRST202', 'message': 'RPC unavailable'}),
          404,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      if (!noEffect) {
        erased = true;
        repo.rows = repo.rows.where((m) => m.id != row.id).toList();
      }
      body = null;
    } else {
      throw StateError('Unexpected erasure endpoint: ${request.url.path}');
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

Finder get _everyoneDialog =>
    find.byKey(const Key('community-message-delete-everyone-dialog'));
Finder get _everyoneConfirm =>
    find.byKey(const Key('community-message-delete-everyone-confirm'));
Future<void> _openEveryone(WidgetTester tester) async {
  await tester.tap(_messageActions(_messageId));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const Key('community-message-delete-for-everyone-$_messageId')),
  );
  await tester.pumpAndSettle();
  expect(_everyoneDialog, findsOneWidget);
}

Future<void> _callEveryone(
  CommunityRepository repo,
  CommunityMessage row,
) async => (repo as dynamic).deleteMessageForEveryone(
  row,
); // Baseline runtime feature absence, not compile-only RED.
void _messageEveryoneDeletionCases(
  _AuthFixture Function() auth,
  _Repository Function() repo,
) {
  _case('Everyone menu is sender-only while For me remains available to both', (
    tester,
  ) async {
    for (final incoming in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final r = repo()..rows = [_everyoneRow(incoming: incoming)];
      await _mount(tester, r);
      await tester.pumpAndSettle();
      await tester.tap(_messageActions(_messageId));
      await tester.pumpAndSettle();
      expect(find.text('Delete for me'), findsOneWidget);
      expect(
        find.text('Delete for everyone'),
        incoming ? findsNothing : findsOneWidget,
      );
      expect(find.text('Report'), incoming ? findsOneWidget : findsNothing);
    }
  });
  _case(
    'Everyone cancel preserves draft; explicit confirm verifies dedicated RPC and absence',
    (tester) async {
      final r = repo()..rows = [_everyoneRow()];
      final server = _EveryoneDeleteServer(auth(), r, r.rows.single);
      await _mount(tester, r);
      await tester.pumpAndSettle();
      await tester.enterText(_composer, 'Preserve this own draft');
      await _openEveryone(tester);
      expect(
        find.text(
          'This removes the message from both BIL mailboxes. It may already have been seen or saved.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('community-message-delete-everyone-cancel')),
      );
      await tester.pumpAndSettle();
      expect(server.order, isEmpty);
      expect(find.text('Owned everyone fixture'), findsOneWidget);
      expect(
        tester.widget<TextField>(_composer).controller!.text,
        'Preserve this own draft',
      );
      await _openEveryone(tester);
      await tester.tap(_everyoneConfirm);
      await tester.pumpAndSettle();
      expect(server.order, ['read', 'everyone', 'read']);
      expect(server.erased, isTrue);
      expect(find.text('Owned everyone fixture'), findsNothing);
      expect(find.text('Message deleted for everyone.'), findsOneWidget);
      expect(
        tester.widget<TextField>(_composer).controller!.text,
        'Preserve this own draft',
      );
    },
  );
  _case(
    'unavailable RPC or HTTP acknowledgement without erasure cannot claim success',
    (tester) async {
      final r = repo()..rows = [_everyoneRow()];
      final server = _EveryoneDeleteServer(auth(), r, r.rows.single)
        ..noEffect = true;
      await _mount(tester, r);
      await tester.pumpAndSettle();
      await _openEveryone(tester);
      await tester.tap(_everyoneConfirm);
      await tester.pumpAndSettle();
      expect(server.order, ['read', 'everyone', 'read']);
      expect(find.text('Owned everyone fixture'), findsOneWidget);
      expect(find.text('Message deleted for everyone.'), findsNothing);
      server.failRpc = true;
      await _openEveryone(tester);
      await tester.tap(_everyoneConfirm);
      await tester.pumpAndSettle();
      expect(server.deletes, 2);
      expect(find.text('Owned everyone fixture'), findsOneWidget);
      expect(find.text('Message deleted for everyone.'), findsNothing);
      expect(find.text(_deleteFailure), findsOneWidget);
    },
  );
  for (final heldRpc in [false, true]) {
    _case(
      'Everyone owner ABA fences ${heldRpc ? 'held RPC completion' : 'confirmation'}',
      (tester) async {
        final r = repo()..rows = [_everyoneRow()];
        final server = _EveryoneDeleteServer(auth(), r, r.rows.single);
        if (heldRpc) server.holdRpc = Completer<void>();
        await _mount(tester, r);
        await tester.pumpAndSettle();
        await _openEveryone(tester);
        if (heldRpc) {
          await tester.tap(_everyoneConfirm);
          await tester.pump();
          expect(server.deletes, 1);
        }
        await auth().roundTrip();
        await tester.pump();
        server.holdRpc?.complete();
        await tester.pumpAndSettle();
        expect(_everyoneDialog, findsNothing);
        expect(find.text('Message deleted for everyone.'), findsNothing);
        expect(heldRpc ? server.reads : server.order.length, heldRpc ? 1 : 0);
      },
    );
  }
  test(
    'repository keeps sender/identity guards and erases even after own For-me hiding',
    () async {
      final r = repo()..rows = [_everyoneRow()];
      final row = r.rows.single;
      final server = _EveryoneDeleteServer(auth(), r, row)..hiddenBefore = true;
      await _callEveryone(r, row);
      expect(server.order, ['read', 'everyone', 'read']);
      expect(server.erased, isTrue);
      await expectLater(
        _callEveryone(r, _everyoneRow(incoming: true)),
        throwsArgumentError,
      );
      final foreign = CommunityMessage(
        id: _messageId,
        senderId: _ownerB,
        recipientId: _peer,
        body: 'Foreign test row',
        createdAt: DateTime.utc(2026),
      );
      await expectLater(_callEveryone(r, foreign), throwsArgumentError);
      expect(server.deletes, 1);
      server.erased = false;
      server.hiddenBefore = false;
      server.wrongIdentity = true;
      await expectLater(_callEveryone(r, row), throwsFormatException);
      expect(server.deletes, 1);
      // Exercise the production presence method too, not only the widget seam.
      var presenceCalls = 0;
      auth().dataRequest = (request) async {
        presenceCalls++;
        expect(request.method, 'GET');
        expect(request.url.path, '/rest/v1/bil_messages');
        expect(
          request.url.queryParameters['select'],
          'id,sender_id,recipient_id',
        );
        expect(request.url.queryParameters['id'], 'in.("$_messageId")');
        final pair = request.url.queryParameters['or']!;
        expect(pair, contains('sender_id.eq.$_ownerA,recipient_id.eq.$_peer'));
        expect(pair, contains('sender_id.eq.$_peer,recipient_id.eq.$_ownerA'));
        return http.Response(
          jsonEncode([
            {
              'id': row.id,
              'sender_id': row.senderId,
              'recipient_id': row.recipientId,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      };
      final actual = CommunityRepository(auth().client);
      expect(await actual.loadVisibleConversationMessageIds(_peer, [row.id]), {
        row.id,
      });
      await expectLater(
        actual.loadVisibleConversationMessageIds(_ownerA, [row.id]),
        throwsArgumentError,
      );
      expect(presenceCalls, 1);
    },
  );
  test('Everyone held metadata owner ABA cannot reach RPC', () async {
    final r = repo()..rows = [_everyoneRow()];
    final server = _EveryoneDeleteServer(auth(), r, r.rows.single)
      ..holdPre = Completer<void>();
    final action = _callEveryone(r, r.rows.single);
    final expected = expectLater(
      action,
      throwsA(isA<CommunityOwnerOperationCancelled>()),
    );
    await Future<void>.delayed(Duration.zero);
    await auth().roundTrip();
    await Future<void>.delayed(Duration.zero);
    server.holdPre!.complete();
    await expected;
    expect(server.order, ['read']);
  });
  _case(
    'realtime reload prunes an erased older row beyond stream one-row cache',
    (tester) async {
      final r = repo();
      r.rows = List.generate(
        50,
        (i) => CommunityMessage(
          id: '77777777-7777-4777-8777-${i.toString().padLeft(12, '0')}',
          senderId: _peer,
          recipientId: _ownerA,
          body: 'Latest fixture $i',
          createdAt: DateTime.utc(2026, 11, 19, 12, i),
        ),
      );
      r.olderRows = [
        CommunityMessage(
          id: _messageId,
          senderId: _peer,
          recipientId: _ownerA,
          body: 'Older erased fixture',
          createdAt: DateTime.utc(2026, 11, 18),
        ),
      ];
      await _mount(tester, r);
      await tester.pumpAndSettle();
      final history = find.byKey(const Key('community-message-history'));
      final controller = tester.widget<ListView>(history).controller!;
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('community-chat-load-older'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Older erased fixture'), findsOneWidget);
      r.olderRows = [];
      r.changes.add(null);
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Older erased fixture'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  _case(
    'presence fallback is foreground-only and removes missed DELETE without idle reloads',
    (tester) async {
      final r = repo()
        ..rows = [
          _everyoneRow(incoming: true),
          _message(id: _secondId, body: 'Unchanged cached fixture'),
        ];
      _lifecycle(tester, resumed: true);
      await _mount(tester, r);
      await tester.pumpAndSettle();
      final loads = r.loads.length;
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(r.visibilityReads, hasLength(1));
      expect(r.loads, hasLength(loads));
      expect(find.text('Owned everyone fixture'), findsOneWidget);
      final nav = Navigator.of(tester.element(_composer));
      unawaited(
        nav.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Covered')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      r.rows = [_message(id: _secondId, body: 'Unchanged cached fixture')];
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(r.visibilityReads, hasLength(1));
      nav.pop();
      await tester.pumpAndSettle();
      _lifecycle(tester, resumed: false);
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(r.visibilityReads, hasLength(1));
      _lifecycle(tester, resumed: true);
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(r.visibilityReads, hasLength(2));
      expect(find.text('Owned everyone fixture'), findsNothing);
      expect(find.text('Unchanged cached fixture'), findsOneWidget);
      expect(r.loads, hasLength(loads));
    },
  );
  _case(
    'presence is single-flight; unknown reads preserve text and late owner ABA is fenced',
    (tester) async {
      final r = repo()
        ..rows = [_everyoneRow(incoming: true)]
        ..pendingVisibility = Completer<Set<String>>();
      _lifecycle(tester, resumed: true);
      await _mount(tester, r);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(r.visibilityReads, hasLength(1));
      await tester.pump(const Duration(seconds: 30));
      expect(r.visibilityReads, hasLength(1));
      r.pendingVisibility!.completeError(
        StateError('Local fixture unavailable'),
      );
      r.pendingVisibility = null;
      await tester.pumpAndSettle();
      expect(find.text('Owned everyone fixture'), findsOneWidget);
      r.pendingVisibility = Completer<Set<String>>();
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(r.visibilityReads, hasLength(2));
      await auth().roundTrip();
      await tester.pump();
      r.pendingVisibility!.complete({});
      r.pendingVisibility = null;
      await tester.pumpAndSettle();
      expect(_composer, findsNothing);
      expect(find.text('Message deleted for everyone.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  _case(
    'held presence prunes only queried missing IDs and retains newly loaded history',
    (tester) async {
      final latest = List.generate(
        50,
        (index) => CommunityMessage(
          id: '77777777-7777-4777-8777-${index.toString().padLeft(12, '0')}',
          senderId: _peer,
          recipientId: _ownerA,
          body: 'Retained latest fixture $index',
          createdAt: DateTime.utc(2026, 11, 19, 12, index),
        ),
      );
      final latestIds = latest.map((row) => row.id).toSet();
      final held = Completer<Set<String>>();
      final r = repo()
        ..rows = latest
        ..olderRows = [
          CommunityMessage(
            id: _messageId,
            senderId: _peer,
            recipientId: _ownerA,
            body: 'Newly loaded older row must survive',
            createdAt: DateTime.utc(2026, 11, 18),
          ),
        ]
        ..pendingVisibility = held;
      try {
        _lifecycle(tester, resumed: true);
        await _mount(tester, r);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 15));
        await tester.pump();
        expect(r.visibilityReads, hasLength(1));
        expect(r.visibilityReads.single.toSet(), latestIds);
        expect(r.visibilityReads.single, isNot(contains(_messageId)));
        final history = find.byKey(const Key('community-message-history'));
        final controller = tester.widget<ListView>(history).controller!;
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final loadOlder = find.byKey(const Key('community-chat-load-older'));
        await tester.ensureVisible(loadOlder);
        await tester.tap(loadOlder);
        await tester.pumpAndSettle();
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          find.text('Newly loaded older row must survive'),
          findsOneWidget,
        );
        expect(
          (tester.widget<ListView>(history).childrenDelegate
                  as SliverChildBuilderDelegate)
              .childCount,
          51,
        );
        expect(r.visibilityReads, hasLength(1));
        held.complete(latestIds.difference({latest.first.id}));
        r.pendingVisibility = null;
        await tester.pumpAndSettle();
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          find.text('Newly loaded older row must survive'),
          findsOneWidget,
        );
        expect(find.text('Retained latest fixture 1'), findsOneWidget);
        expect(find.text('Retained latest fixture 0'), findsNothing);
        expect(
          (tester.widget<ListView>(history).childrenDelegate
                  as SliverChildBuilderDelegate)
              .childCount,
          50,
        );
        expect(tester.takeException(), isNull);
      } finally {
        // Release a failed fixture too; never strand an owner operation's listener.
        if (!held.isCompleted) {
          held.complete(latestIds);
        }
        r.pendingVisibility = null;
        await tester.pump();
      }
    },
  );
  _case('same-owner incoming reload retires an older held presence response', (
    tester,
  ) async {
    final held = Completer<Set<String>>();
    final r = repo()
      ..rows = [_message(body: 'Existing row before incoming reload')]
      ..pendingVisibility = held;
    try {
      _lifecycle(tester, resumed: true);
      await _mount(tester, r);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(r.visibilityReads, hasLength(1));
      expect(r.visibilityReads.single, [_messageId]);
      final loadsBefore = r.loads.length;
      r.rows = [
        ...r.rows,
        _message(id: _secondId, body: 'New same-owner incoming row'),
      ];
      r.changes.add(null);
      await tester.pumpAndSettle();
      expect(r.loads.length, loadsBefore + 1);
      expect(find.text('New same-owner incoming row'), findsOneWidget);
      held.complete(<String>{});
      r.pendingVisibility = null;
      await tester.pumpAndSettle();
      expect(find.text('Existing row before incoming reload'), findsOneWidget);
      expect(find.text('New same-owner incoming row'), findsOneWidget);
      expect(r.visibilityReads, hasLength(1));
      expect(tester.takeException(), isNull);
    } finally {
      if (!held.isCompleted) {
        held.complete({_messageId});
      }
      r.pendingVisibility = null;
      await tester.pump();
    }
  });
  _case(
    'held recent presence keeps successful older page and publishes fresh incoming head',
    (tester) async {
      List<CommunityMessage> page(int hour, String label) => List.generate(
        50,
        (index) => CommunityMessage(
          id: '88888888-8888-4888-8888-${(hour * 100 + index).toString().padLeft(12, '0')}',
          senderId: _peer,
          recipientId: _ownerA,
          body: '$label $index',
          createdAt: DateTime.utc(2026, 11, 19, hour, index),
        ),
      );
      final recent = page(12, 'Original recent');
      final firstPage = page(11, 'First older page');
      final secondPage = page(10, 'Second older page');
      final incoming = CommunityMessage(
        id: _secondId,
        senderId: _peer,
        recipientId: _ownerA,
        body: 'Fresh incoming head survives concurrent pagination',
        createdAt: DateTime.utc(2026, 11, 19, 12, 50),
      );
      final r = repo()
        ..rows = recent
        ..olderRows = firstPage;
      final held = Completer<Set<String>>();
      Set<String> queried = {};
      try {
        _lifecycle(tester, resumed: true);
        await _mount(tester, r);
        await tester.pumpAndSettle();
        await tester.enterText(_composer, 'Preserve own unsent draft');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final history = find.byKey(const Key('community-message-history'));
        final controller = tester.widget<ListView>(history).controller!;
        Future<void> loadOlder() async {
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          final button = find.byKey(const Key('community-chat-load-older'));
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await loadOlder();
        expect(r.olderCursors, [recent.first.id]);
        r.pendingVisibility = held;
        r.rows = [...recent.skip(1), incoming];
        final loadsBefore = r.loads.length;
        r.changes.add(null);
        await tester.pump();
        await tester.pump();
        expect(r.loads.length, loadsBefore + 1);
        expect(r.visibilityReads, hasLength(1));
        queried = r.visibilityReads.single.toSet();
        expect(queried, containsAll(firstPage.map((row) => row.id)));
        expect(queried, contains(recent.first.id));
        expect(
          queried.intersection(secondPage.map((row) => row.id).toSet()),
          isEmpty,
        );
        r.olderRows = secondPage;
        await loadOlder();
        expect(r.olderCursors, [recent.first.id, firstPage.first.id]);
        final paged = tester.widget<ListView>(history);
        for (final row in secondPage) {
          expect(
            (paged.childrenDelegate as SliverChildBuilderDelegate)
                .findChildIndexCallback!(ValueKey(row.id)),
            isNotNull,
          );
        }
        // The held authoritative result disproves one queried old row only.
        held.complete(queried.difference({firstPage.first.id}));
        r.pendingVisibility = null;
        await tester.pumpAndSettle();
        final merged = tester.widget<ListView>(history);
        expect(
          (merged.childrenDelegate as SliverChildBuilderDelegate)
              .findChildIndexCallback!(ValueKey(incoming.id)),
          isNotNull,
        );
        expect(
          (merged.childrenDelegate as SliverChildBuilderDelegate)
              .findChildIndexCallback!(ValueKey(firstPage.first.id)),
          isNull,
        );
        for (final row in [
          ...recent,
          ...firstPage.skip(1),
          ...secondPage,
          incoming,
        ]) {
          expect(
            (merged.childrenDelegate as SliverChildBuilderDelegate)
                .findChildIndexCallback!(ValueKey(row.id)),
            isNotNull,
          );
        }
        expect(
          (merged.childrenDelegate as SliverChildBuilderDelegate)
              .findChildIndexCallback!(ValueKey(firstPage[1].id)),
          isNotNull,
        );
        expect(
          (merged.childrenDelegate as SliverChildBuilderDelegate).childCount,
          151,
        );
        controller.jumpTo(controller.position.minScrollExtent);
        await tester.pumpAndSettle();
        expect(
          find.text('Fresh incoming head survives concurrent pagination'),
          findsOneWidget,
        );
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(find.text('Second older page 0'), findsOneWidget);
        expect(
          tester.widget<TextField>(_composer).controller!.text,
          'Preserve own unsent draft',
        );
        expect(r.visibilityReads, hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        if (!held.isCompleted) held.complete(queried);
        r.pendingVisibility = null;
        await tester.pump();
      }
    },
  );
  _case(
    'localized Everyone confirmation stays reachable320dp2.5x and all locale rows resolve',
    (tester) async {
      expect(CommunityChatRuntimeCopy.balanced, isTrue);
      for (final tag in CommunityChatRuntimeCopy.values.keys) {
        for (final text in [
          'Delete for everyone',
          'Delete this message for everyone?',
          'This removes the message from both BIL mailboxes. It may already have been seen or saved.',
          'Message deleted for everyone.',
        ]) {
          final translated = CommunityChatRuntimeCopy.resolve(text, tag);
          expect(translated, isNotNull);
          expect(translated!.trim(), isNotEmpty);
          expect(translated, isNot(text));
        }
      }
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final r = repo()..rows = [_everyoneRow()];
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2.5)),
              child: child!,
            ),
            home: CommunityChatPage(
              userId: _peer,
              displayName: 'Private chat',
              repository: r,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _openEveryone(tester);
        expect(_everyoneConfirm.hitTestable(), findsOneWidget);
        final cancel = find.byKey(
          const Key('community-message-delete-everyone-cancel'),
        );
        expect(cancel.hitTestable(), findsOneWidget);
        expect(
          tester.getSize(_everyoneConfirm).height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      }
    },
  );
}
