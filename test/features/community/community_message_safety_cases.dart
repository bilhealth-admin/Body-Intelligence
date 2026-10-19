part of 'community_chat_auth_session_test.dart';

void _messageSafetyCases(
  _AuthFixture Function() getAuth,
  _Repository Function() getRepo,
) {
  Future<void> openReport(WidgetTester tester) async {
    await tester.tap(
      find.byKey(
        const Key(
          'community-message-safety-55555555-5555-4555-8555-555555555555',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('community-report-reason-tap-harassment')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'private message report sends only selected target and reason after confirmation',
    (tester) async {
      final auth = getAuth(), repo = getRepo();
      final reports = <Map<String, dynamic>>[];
      auth.dataRequest = (request) async {
        expect(request.url.path, '/rest/v1/bil_community_reports');
        reports.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('', 201, request: request);
      };
      await _mount(tester, repo);
      await tester.pumpAndSettle();
      await openReport(tester);
      expect(reports, isEmpty);
      final send = find.byKey(const Key('community-report-submit'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(reports, hasLength(1));
      expect(reports.single, {
        'reporter_id': _ownerA,
        'target_kind': 'message',
        'target_id': _messageId,
        'reason': 'harassment',
      });
      expect(repo.sends, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'confirmed private block uses peer identity and removes composer and transcript',
    (tester) async {
      final auth = getAuth(), repo = getRepo();
      var blocked = 0;
      auth.dataRequest = (request) async {
        expect(request.url.path, '/rest/v1/rpc/bil_block_community_member');
        expect(jsonDecode(request.body), {'p_blocked_id': _peer});
        blocked++;
        return http.Response('', 204, request: request);
      };
      await _mount(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const Key(
            'community-message-safety-55555555-5555-4555-8555-555555555555',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block member'));
      await tester.pumpAndSettle();
      expect(blocked, 0);
      await tester.tap(
        find.byKey(const Key('community-message-confirm-block')),
      );
      await tester.pumpAndSettle();
      expect(blocked, 1);
      expect(find.text('Member blocked.'), findsOneWidget);
      expect(_composer, findsNothing);
      expect(find.text('Private A transcript'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final aba in [false, true]) {
    testWidgets(
      'private report cannot send after ${aba ? 'A-B-A' : 'A-B'} owner change',
      (tester) async {
        final auth = getAuth(), repo = getRepo();
        var requests = 0;
        auth.dataRequest = (request) async {
          requests++;
          return http.Response('', 201, request: request);
        };
        await _mount(tester, repo);
        await tester.pumpAndSettle();
        await openReport(tester);
        if (aba) {
          await auth.roundTrip();
        } else {
          await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
        }
        await tester.pumpAndSettle();
        final send = find.byKey(const Key('community-report-submit'));
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(requests, 0);
        expect(repo.sends, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
