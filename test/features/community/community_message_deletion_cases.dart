part of 'community_chat_auth_session_test.dart';

CommunityMessage _deletableMessage({
  bool incoming = false,
  String id = _messageId,
}) => CommunityMessage(
  id: id,
  senderId: incoming ? _peer : _ownerA,
  recipientId: incoming ? _ownerA : _peer,
  body: '[BIL-SUBJECT]Synthetic subject\nSynthetic body 👩‍💻',
  createdAt: DateTime.utc(2026, 11, 16, 18),
);

class _MessageDeleteServer {
  _MessageDeleteServer(this.auth, this.repo, this.message) {
    auth.dataRequest = request;
  }
  final _AuthFixture auth;
  final _Repository repo;
  final CommunityMessage message;
  final order = <String>[];
  final failReads = <int>{};
  bool hidden = false, failRpc = false, noEffect = false, wrongIdentity = false;
  int reads = 0, deletes = 0;
  Completer<void>? waitPre, waitRpc, waitPost;

  Future<http.Response> request(http.Request request) async {
    Object? body;
    if (request.method == 'GET' &&
        request.url.path == '/rest/v1/bil_messages') {
      reads++;
      order.add('read');
      expect(
        request.url.queryParameters['select'],
        'id,sender_id,recipient_id',
      );
      expect(request.url.queryParameters['id'], 'eq.${message.id}');
      expect(request.url.queryParameters['or'], contains(_ownerA));
      await (reads == 1 ? waitPre?.future : waitPost?.future);
      if (failReads.contains(reads)) {
        return http.Response(
          jsonEncode({'code': '42501', 'message': 'metadata read denied'}),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      body = [
        if (!hidden)
          {
            'id': message.id,
            'sender_id': wrongIdentity ? _other : message.senderId,
            'recipient_id': message.recipientId,
          },
      ];
    } else if (request.method == 'POST' &&
        request.url.path == '/rest/v1/rpc/bil_delete_message') {
      deletes++;
      order.add('delete');
      expect(jsonDecode(request.body), {'p_message_id': message.id});
      await waitRpc?.future;
      if (failRpc) {
        return http.Response(
          jsonEncode({'code': '42501', 'message': 'delete refused'}),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      if (!noEffect) {
        hidden = true;
        repo.rows = repo.rows.where((m) => m.id != message.id).toList();
      }
      body = null; // Actual deployed RPC returns void, never a success count.
    } else {
      throw StateError('Unexpected deletion request: ${request.url}');
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

Finder _messageActions(String id) =>
    find.byKey(Key('community-message-safety-$id'));
Finder get _deleteConfirm =>
    find.byKey(const Key('community-message-delete-confirm'));
Finder get _deleteDialog =>
    find.byKey(const Key('community-message-delete-dialog'));
const _deletedCopy = 'Message removed from your mailbox.';
const _deleteFailure = 'Could not complete that action safely. Try again.';

Future<void> _openMessageDelete(WidgetTester tester, String id) async {
  await tester.tap(_messageActions(id));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('community-message-delete-for-me-$id')));
  await tester.pumpAndSettle();
  expect(_deleteDialog, findsOneWidget);
}

void _messageDeletionCases(
  _AuthFixture Function() getAuth,
  _Repository Function() getRepo,
) {
  test(
    'delete repository verifies exact metadata RPC and actor absence',
    () async {
      final repo = getRepo()..rows = [_deletableMessage()];
      final server = _MessageDeleteServer(getAuth(), repo, repo.rows.single);
      await repo.deleteMessageForCurrentUser(repo.rows.single);
      expect(server.order, ['read', 'delete', 'read']);
    },
  );
  _case('own message exposes an explicit Delete for me action', (tester) async {
    final repo = getRepo()..rows = [_deletableMessage()];
    await _mount(tester, repo);
    await tester.pumpAndSettle();
    expect(_messageActions(_messageId), findsOneWidget);
    await tester.tap(_messageActions(_messageId));
    await tester.pumpAndSettle();
    expect(find.text('Delete for me'), findsOneWidget);
    expect(find.text('Report'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });
  _case('recipient keeps Delete for me alongside Report and Block', (
    tester,
  ) async {
    final repo = getRepo()..rows = [_deletableMessage(incoming: true)];
    await _mount(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(_messageActions(_messageId));
    await tester.pumpAndSettle();
    for (final text in ['Delete for me', 'Report', 'Block member']) {
      expect(find.text(text), findsOneWidget);
    }
  });
  _case('nonparticipant has no deletion action or metadata request', (
    tester,
  ) async {
    final repo = getRepo();
    final row = CommunityMessage(
      id: _messageId,
      senderId: _ownerB,
      recipientId: _peer,
      body: 'Synthetic nonparticipant fixture',
      createdAt: DateTime.utc(2026),
    );
    repo.rows = [row];
    final server = _MessageDeleteServer(getAuth(), repo, row);
    await _mount(tester, repo);
    await tester.pumpAndSettle();
    expect(_messageActions(_messageId), findsNothing);
    await expectLater(
      repo.deleteMessageForCurrentUser(row),
      throwsArgumentError,
    );
    expect(server.order, isEmpty);
  });
  _case('cancel leaves raw transcript and draft without any deletion request', (
    tester,
  ) async {
    final repo = getRepo()..rows = [_deletableMessage()];
    final row = repo.rows.single;
    final server = _MessageDeleteServer(getAuth(), repo, row);
    await _mount(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(_composer, 'Keep this private draft');
    await _openMessageDelete(tester, row.id);
    expect(
      find.text(
        'Only your copy is removed. The other participant keeps their copy.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('community-message-delete-cancel')));
    await tester.pumpAndSettle();
    expect(server.order, isEmpty);
    expect(
      find.text('Synthetic subject\nSynthetic body 👩‍💻'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(_composer).controller!.text,
      'Keep this private draft',
    );
    expect(row.body, '[BIL-SUBJECT]Synthetic subject\nSynthetic body 👩‍💻');
  });
  for (final incoming in [false, true]) {
    _case(
      '${incoming ? 'recipient' : 'sender'} removes only verified actor mailbox row',
      (tester) async {
        final repo = getRepo()..rows = [_deletableMessage(incoming: incoming)];
        final row = repo.rows.single;
        final server = _MessageDeleteServer(getAuth(), repo, row);
        await _mount(tester, repo);
        await tester.pumpAndSettle();
        await _openMessageDelete(tester, row.id);
        await tester.tap(_deleteConfirm);
        await tester.pumpAndSettle();
        expect(server.order, ['read', 'delete', 'read']);
        expect(server.deletes, 1);
        expect(
          find.byKey(ValueKey('community-message-body-${row.id}')),
          findsNothing,
        );
        expect(find.text(_deletedCopy), findsOneWidget);
        expect(repo.sends, isEmpty);
        expect(repo.operationRequests, isEmpty);
        expect(
          row.body,
          '[BIL-SUBJECT]Synthetic subject\nSynthetic body 👩‍💻',
        );
      },
    );
  }
  _case(
    'pending RPC and duplicate confirmation never remove optimistically or pop chat',
    (tester) async {
      final repo = getRepo()..rows = [_deletableMessage()];
      final server = _MessageDeleteServer(getAuth(), repo, repo.rows.single)
        ..waitRpc = Completer<void>();
      await _mount(tester, repo);
      await tester.pumpAndSettle();
      await _openMessageDelete(tester, _messageId);
      final confirm = tester.widget<FilledButton>(_deleteConfirm).onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(server.deletes, 1);
      expect(server.reads, 1);
      expect(
        find.text('Synthetic subject\nSynthetic body 👩‍💻'),
        findsOneWidget,
      );
      expect(find.text(_deletedCopy), findsNothing);
      expect(
        tester
            .widget<PopupMenuButton<String>>(_messageActions(_messageId))
            .enabled,
        isFalse,
      );
      server.waitRpc!.complete();
      await tester.pumpAndSettle();
      expect(server.deletes, 1);
      expect(_composer, findsOneWidget);
      expect(find.text(_deletedCopy), findsOneWidget);
    },
  );
  _case('void RPC acknowledgement waits for canonical postread before hiding', (
    tester,
  ) async {
    final repo = getRepo()..rows = [_deletableMessage()];
    final server = _MessageDeleteServer(getAuth(), repo, repo.rows.single)
      ..waitPost = Completer<void>();
    await _mount(tester, repo);
    await tester.pumpAndSettle();
    await _openMessageDelete(tester, _messageId);
    await tester.tap(_deleteConfirm);
    await tester.pumpAndSettle();
    expect(server.order, ['read', 'delete', 'read']);
    expect(
      find.text('Synthetic subject\nSynthetic body 👩‍💻'),
      findsOneWidget,
    );
    expect(find.text(_deletedCopy), findsNothing);
    server.waitPost!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Synthetic subject\nSynthetic body 👩‍💻'), findsNothing);
    expect(find.text(_deletedCopy), findsOneWidget);
  });
  for (final failRead in [1, 2]) {
    _case(
      'metadata403 at read$failRead keeps the row without a false success',
      (tester) async {
        final repo = getRepo()..rows = [_deletableMessage()];
        final server = _MessageDeleteServer(getAuth(), repo, repo.rows.single)
          ..failReads.add(failRead);
        await _mount(tester, repo);
        await tester.pumpAndSettle();
        await _openMessageDelete(tester, _messageId);
        await tester.tap(_deleteConfirm);
        await tester.pumpAndSettle();
        expect(server.deletes, failRead == 1 ? 0 : 1);
        expect(
          find.text('Synthetic subject\nSynthetic body 👩‍💻'),
          findsOneWidget,
        );
        expect(find.text(_deletedCopy), findsNothing);
        expect(find.text(_deleteFailure), findsOneWidget);
        if (failRead == 2) {
          server.failReads.clear();
          await _openMessageDelete(tester, _messageId);
          await tester.tap(_deleteConfirm);
          await tester.pumpAndSettle();
          expect(
            server.deletes,
            1,
            reason: 'already hidden retry must not replay the RPC',
          );
          expect(
            find.text('Synthetic subject\nSynthetic body 👩‍💻'),
            findsNothing,
          );
        }
      },
    );
  }
  for (final failure in ['rpc', 'no-effect', 'identity']) {
    _case('delete $failure failure retains the message and composer', (
      tester,
    ) async {
      final repo = getRepo()..rows = [_deletableMessage()];
      final server = _MessageDeleteServer(getAuth(), repo, repo.rows.single)
        ..failRpc = failure == 'rpc'
        ..noEffect = failure == 'no-effect'
        ..wrongIdentity = failure == 'identity';
      await _mount(tester, repo);
      await tester.pumpAndSettle();
      await tester.enterText(_composer, 'Unsent draft stays');
      await _openMessageDelete(tester, _messageId);
      await tester.tap(_deleteConfirm);
      await tester.pumpAndSettle();
      expect(server.deletes, failure == 'identity' ? 0 : 1);
      expect(
        find.text('Synthetic subject\nSynthetic body 👩‍💻'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(_composer).controller!.text,
        'Unsent draft stays',
      );
      expect(find.text(_deletedCopy), findsNothing);
      expect(find.text(_deleteFailure), findsOneWidget);
    });
  }
  _case(
    'already-hidden actor copy closes after canonical read without another RPC',
    (tester) async {
      final repo = getRepo()..rows = [_deletableMessage()];
      final server = _MessageDeleteServer(getAuth(), repo, repo.rows.single)
        ..hidden = true;
      await _mount(tester, repo);
      await tester.pumpAndSettle();
      await _openMessageDelete(tester, _messageId);
      await tester.tap(_deleteConfirm);
      await tester.pumpAndSettle();
      expect(server.order, ['read']);
      expect(
        find.text('Synthetic subject\nSynthetic body 👩‍💻'),
        findsNothing,
      );
    },
  );
  for (final aba in [false, true]) {
    for (final phase in ['dialog', 'pre', 'rpc', 'post']) {
      _case('delete $phase is fenced across ${aba ? 'queued A-B-A' : 'A-B'}', (
        tester,
      ) async {
        final auth = getAuth(), repo = getRepo()..rows = [_deletableMessage()];
        final server = _MessageDeleteServer(auth, repo, repo.rows.single);
        final gate = Completer<void>();
        if (phase == 'pre') server.waitPre = gate;
        if (phase == 'rpc') server.waitRpc = gate;
        if (phase == 'post') server.waitPost = gate;
        await _mount(tester, repo);
        await tester.pumpAndSettle();
        await _openMessageDelete(tester, _messageId);
        if (phase != 'dialog') {
          await tester.tap(_deleteConfirm);
          await tester.pumpAndSettle();
        }
        if (aba) {
          await auth.roundTrip();
        } else {
          await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
        }
        await tester.pumpAndSettle();
        if (phase != 'dialog') gate.complete();
        await tester.pumpAndSettle();
        expect(_deleteDialog, findsNothing);
        expect(find.text(_deletedCopy), findsNothing);
        expect(find.text(_deleteFailure), findsNothing);
        expect(server.deletes, ['rpc', 'post'].contains(phase) ? 1 : 0);
        if (phase == 'rpc') expect(server.reads, 1);
        expect(repo.sends, isEmpty);
      });
    }
  }
  _case(
    'changing peer dismisses only the stale confirmation without a request',
    (tester) async {
      final repo = getRepo()..rows = [_deletableMessage()];
      final server = _MessageDeleteServer(getAuth(), repo, repo.rows.single);
      await _mount(tester, repo);
      await tester.pumpAndSettle();
      await _openMessageDelete(tester, _messageId);
      await _mount(tester, repo, peer: _other);
      await tester.pumpAndSettle();
      expect(_deleteDialog, findsNothing);
      expect(_composer, findsOneWidget);
      expect(server.order, isEmpty);
    },
  );
  _case('a delayed old head read cannot resurrect verified deletion', (
    tester,
  ) async {
    final repo = getRepo()..rows = [_deletableMessage()];
    final row = repo.rows.single;
    final server = _MessageDeleteServer(getAuth(), repo, row);
    await _mount(tester, repo);
    await tester.pumpAndSettle();
    final pending = Completer<List<CommunityMessage>>();
    repo.pendingLoad = pending;
    repo.changes.add(null);
    await tester.pump();
    await tester.pump();
    await _openMessageDelete(tester, row.id);
    await tester.tap(_deleteConfirm);
    await tester.pumpAndSettle();
    pending.complete([row]);
    await tester.pumpAndSettle();
    expect(server.deletes, 1);
    expect(find.text('Synthetic subject\nSynthetic body 👩‍💻'), findsNothing);
  });
  _case('equal bodies do not delete another message identity', (tester) async {
    final first = _deletableMessage(),
        second = _deletableMessage(id: _secondId);
    final repo = getRepo()..rows = [first, second];
    _MessageDeleteServer(getAuth(), repo, first);
    await _mount(tester, repo);
    await tester.pumpAndSettle();
    await _openMessageDelete(tester, first.id);
    await tester.tap(_deleteConfirm);
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('community-message-body-${first.id}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('community-message-body-${second.id}')),
      findsOneWidget,
    );
  });
  _case(
    'deletion keeps ambiguous-send request identity and removed-delivery tombstone',
    (tester) async {
      final repo = getRepo()..rows = [_deletableMessage()];
      final row = repo.rows.single;
      _MessageDeleteServer(getAuth(), repo, row);
      await _mount(tester, repo);
      await tester.pumpAndSettle();
      repo.pendingSend = Completer<void>();
      await tester.enterText(_composer, row.body);
      await tester.tap(_send);
      await tester.pump();
      repo.pendingSend!.completeError(StateError('ambiguous delivery'));
      await tester.pumpAndSettle();
      final request = repo.operationRequests.single;
      await _openMessageDelete(tester, row.id);
      await tester.tap(_deleteConfirm);
      await tester.pumpAndSettle();
      // Let the confirmation snackbar leave the composer hit area.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      repo.pendingSend = Completer<void>();
      await tester.tap(_send);
      await tester.pump();
      repo.pendingSend!.completeError(const CommunityMessageDeliveryRemoved());
      await tester.pumpAndSettle();
      expect(repo.operationRequests, [request, request]);
      expect(repo.sends, [row.body, row.body]);
      expect(tester.widget<TextField>(_composer).controller!.text, row.body);
      expect(
        find.byKey(ValueKey('community-message-body-${row.id}')),
        findsNothing,
      );
      expect(
        find.text(
          'This message was previously delivered and then removed. Your text is kept; no new message was sent.',
        ),
        findsOneWidget,
      );
    },
  );
  _case('Arabic confirmation explains removal of only the actor copy', (
    tester,
  ) async {
    final repo = getRepo()..rows = [_deletableMessage()];
    final server = _MessageDeleteServer(getAuth(), repo, repo.rows.single);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: CommunityChatPage(
          userId: _peer,
          displayName: 'عضو اختباري',
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openMessageDelete(tester, _messageId);
    expect(find.text('حذف من رسائلي'), findsOneWidget);
    expect(
      find.text('تُحذف نسختك فقط. يحتفظ الطرف الآخر بنسخته.'),
      findsOneWidget,
    );
    expect(server.order, isEmpty);
    await tester.tap(find.byKey(const Key('community-message-delete-cancel')));
    await tester.pumpAndSettle();
  });
  _case('delete confirmation stays usable with large text and keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = getRepo()..rows = [_deletableMessage()];
    final server = _MessageDeleteServer(getAuth(), repo, repo.rows.single);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.8),
            viewInsets: const EdgeInsets.only(bottom: 200),
          ),
          child: child!,
        ),
        home: CommunityChatPage(
          userId: _peer,
          displayName: 'QA',
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openMessageDelete(tester, _messageId);
    expect(tester.takeException(), isNull);
    expect(_deleteConfirm.hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-message-delete-cancel')));
    await tester.pumpAndSettle();
    expect(_deleteDialog, findsNothing);
    expect(server.order, isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final retireOwner in [false, true]) {
    _case(
      'queued stale delete confirmation preserves replacement route ${retireOwner ? 'after owner retirement' : 'while dialog is covered'}',
      (tester) async {
        final auth = getAuth(), repo = getRepo()..rows = [_deletableMessage()];
        final server = _MessageDeleteServer(auth, repo, repo.rows.single);
        await _mount(tester, repo);
        await tester.pumpAndSettle();
        await _openMessageDelete(tester, _messageId);
        final oldConfirm = tester
            .widget<FilledButton>(_deleteConfirm)
            .onPressed!;
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        unawaited(
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Replacement route must stay')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (retireOwner) {
          await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
          await tester.pumpAndSettle();
        }
        expect(oldConfirm, returnsNormally);
        await tester.pumpAndSettle();
        expect(find.text('Replacement route must stay'), findsOneWidget);
        expect(server.order, isEmpty);
        expect(_deleteDialog, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
