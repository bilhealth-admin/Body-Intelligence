part of 'community_chat_auth_session_test.dart';

void _visibilityPagingCases(
  _AuthFixture Function() fixture,
  _Repository Function() repository,
) {
  _case('covering a chat discards dwell and restarts it after uncovering', (
    tester,
  ) async {
    final repo = repository();
    await _mount(tester, repo);
    await tester.pump(const Duration(milliseconds: 250));
    final nav = Navigator.of(tester.element(_composer));
    unawaited(
      nav.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(repo.reads, isEmpty);
    nav.pop();
    await tester.pumpAndSettle();
    expect(repo.reads, isEmpty);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(repo.reads, hasLength(1));
  });
  _case('partial readback does not acknowledge the missing message', (
    tester,
  ) async {
    final repo = repository();
    repo.rows = [
      _message(),
      _message(id: _secondId, body: 'Not yet confirmed'),
    ];
    await _mount(tester, repo);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(repo.reads.single.toSet(), {_messageId, _secondId});
    expect(repo.readbacks, 1);
    await tester.drag(
      find.byKey(const Key('community-message-history')),
      const Offset(0, 60),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(repo.reads, hasLength(2));
    expect(repo.reads.last, [_secondId]);
  });
  _case('owner changes during write stop readback and later acknowledgement', (
    tester,
  ) async {
    final repo = repository()..pendingRead = Completer<int>();
    await _mount(tester, repo);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(repo.reads, hasLength(1));
    await fixture().roundTrip();
    await tester.pump();
    repo.pendingRead!.complete(1);
    await tester.pumpAndSettle();
    expect(repo.readbacks, 0);
    expect(_composer, findsNothing);
    expect(tester.takeException(), isNull);
  });
  _case('a new visible row entering during a read write is not lost', (
    tester,
  ) async {
    final repo = repository()..pendingRead = Completer<int>();
    await _mount(tester, repo);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(repo.reads, hasLength(1));
    repo.rows.add(_message(id: _secondId, body: 'Arrived during write'));
    repo.confirmed.add(_secondId);
    repo.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Arrived during write'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 650));
    repo.pendingRead!.complete(1);
    repo.pendingRead = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(repo.reads, hasLength(2));
    expect(repo.reads.last, [_secondId]);
  });
  _case('failed older page keeps transcript and retries the identical cursor', (
    tester,
  ) async {
    final repo = repository();
    repo.rows = [
      for (var i = 50; i < 100; i++)
        CommunityMessage(
          id: '77777777-7777-4777-8777-${i.toString().padLeft(12, '0')}',
          senderId: _peer,
          recipientId: _ownerA,
          body: 'Message $i',
          createdAt: DateTime.utc(2026, 10, 6, 12, i),
        ),
    ];
    repo.failOlder = true;
    await _mount(tester, repo);
    final history = find.byKey(const Key('community-message-history'));
    final controller = tester.widget<ListView>(history).controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('community-chat-load-older'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.olderCursors, [repo.rows.first.id]);
    expect(find.text('Message 50'), findsOneWidget);
    expect(button, findsOneWidget);
    repo.failOlder = false;
    repo.olderRows = [
      CommunityMessage(
        id: _messageId,
        senderId: _peer,
        recipientId: _ownerA,
        body: 'Older recovered',
        createdAt: DateTime.utc(2026, 10, 6, 12),
      ),
    ];
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.olderCursors, [repo.rows.first.id, repo.rows.first.id]);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Older recovered'), findsOneWidget);
    expect(button, findsNothing);
    expect(tester.takeException(), isNull);
  });
  _case('a pending send cannot clear or reload a replacement peer draft', (
    tester,
  ) async {
    final repo = repository()..pendingSend = Completer<void>();
    await _mount(tester, repo);
    await tester.enterText(_composer, 'Old message');
    await tester.tap(_send);
    await tester.pump();
    repo.rows = [_message(peer: _other, body: 'Other peer')];
    await _mount(tester, repo, peer: _other);
    await tester.enterText(_composer, 'New private draft');
    final loads = repo.loads.length;
    repo.pendingSend!.complete();
    await tester.pumpAndSettle();
    expect(repo.loads, hasLength(loads));
    expect(
      tester.widget<TextField>(_composer).controller!.text,
      'New private draft',
    );
    expect(find.text('Other peer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  _case('an emoji menu from a retired peer cannot insert into the new draft', (
    tester,
  ) async {
    final repo = repository();
    await _mount(tester, repo);
    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pumpAndSettle();
    repo.rows = [_message(peer: _other)];
    await _mount(tester, repo, peer: _other);
    await tester.tap(find.text('👋'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_composer).controller!.text, isEmpty);
  });
  _case(
    'realtime failure retains transcript input and older-reading position through retry',
    (tester) async {
      final repo = repository();
      repo.rows = [
        for (var index = 0; index < 30; index++)
          CommunityMessage(
            id: '77777777-7777-4777-8777-${index.toString().padLeft(12, '0')}',
            senderId: _peer,
            recipientId: _ownerA,
            body: 'Older message $index',
            createdAt: DateTime.utc(2026, 10, 6, 12, index),
          ),
      ];
      await _mount(tester, repo);
      await tester.enterText(_composer, 'Unsent preserved');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final history = find.byKey(const Key('community-message-history'));
      final controller = tester.widget<ListView>(history).controller!;
      await tester.drag(history, const Offset(0, 300));
      await tester.pumpAndSettle();
      final offset = controller.offset;
      expect(offset, greaterThan(72));
      final pending = Completer<List<CommunityMessage>>();
      repo.pendingLoad = pending;
      repo.changes.add(null);
      await tester.pump();
      await tester.pump();
      pending.completeError(StateError('offline refresh'));
      await tester.pumpAndSettle();
      expect(history, findsOneWidget);
      expect(controller.offset, closeTo(offset, .5));
      expect(
        tester.widget<TextField>(_composer).controller!.text,
        'Unsent preserved',
      );
      await tester.tap(find.text('Could not load this chat. Try again.'));
      await tester.pumpAndSettle();
      expect(history, findsOneWidget);
      expect(controller.offset, closeTo(offset, .5));
      expect(tester.takeException(), isNull);
    },
  );
  _case(
    'new realtime row still needs its own complete dwell after an earlier write finishes',
    (tester) async {
      final repo = repository()..pendingRead = Completer<int>();
      await _mount(tester, repo);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      expect(repo.reads, hasLength(1));
      repo.rows.add(_message(id: _secondId, body: 'Recent arrival'));
      repo.confirmed.add(_secondId);
      repo.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Recent arrival').hitTestable(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      repo.pendingRead!.complete(1);
      repo.pendingRead = null;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.reads, hasLength(1));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(repo.reads, hasLength(2));
      expect(repo.reads.last, [_secondId]);
    },
  );
  _case('2000 astral codepoints send intact with the codepoint counter', (
    tester,
  ) async {
    final repo = repository()..pendingSend = Completer<void>();
    await _mount(tester, repo);
    final text = '😀' * 2000;
    await tester.enterText(_composer, text);
    await tester.pump();
    expect(find.text('2000/2000'), findsOneWidget);
    await tester.tap(_send);
    await tester.pump();
    expect(repo.sends, [text]);
    repo.pendingSend!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_composer).controller!.text, isEmpty);
  });
}
