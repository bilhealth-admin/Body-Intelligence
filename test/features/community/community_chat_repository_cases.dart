part of 'community_chat_auth_session_test.dart';

CommunityPolicyState _acceptedPolicy() =>
    CommunityPolicyState.fromServerSnapshot({
      'server_now': '2026-10-06T12:00:00Z',
      'status': 'accepted',
      'version': 'test-policy-v1',
      'document_url': 'https://policy.example.invalid/community',
      'effective_at': '2026-10-01T00:00:00Z',
      'accepted': true,
      'accepted_at': '2026-10-02T00:00:00Z',
    });

class _PolicyRepository extends CommunityRepository {
  _PolicyRepository(super.client);
  Completer<CommunityPolicyState>? policy;
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => policy == null ? _acceptedPolicy() : policy!.future;
}

http.Response _jsonResponse(http.Request request, Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);
Map<String, dynamic> _messageJson({
  String id = _messageId,
  String owner = _ownerA,
  String peer = _peer,
  String? readAt,
}) => {
  'id': id,
  'sender_id': peer,
  'recipient_id': owner,
  'body': 'Private message',
  'created_at': '2026-10-06T12:00:00Z',
  'read_at': readAt,
};
void _repositoryCases(_AuthFixture Function() fixture) {
  for (final aba in [false, true]) {
    test(
      'repository policy await cannot insert after ${aba ? 'queued A-B-A' : 'A-B'}',
      () async {
        final auth = fixture();
        final inserts = <http.Request>[];
        auth.dataRequest = (request) async {
          inserts.add(request);
          return _jsonResponse(request, {});
        };
        final repo = _PolicyRepository(auth.client)
          ..policy = Completer<CommunityPolicyState>();
        final send = repo.sendMessage(_peer, 'Private A message');
        final assertion = expectLater(
          send,
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        if (aba) {
          await auth.roundTrip();
        } else {
          await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
        }
        await Future<void>.delayed(Duration.zero);
        repo.policy!.complete(_acceptedPolicy());
        await assertion;
        expect(inserts, isEmpty);
      },
    );
  }
  test(
    'repository Unicode limit matches actual PostgreSQL 2000 code points',
    () async {
      final auth = fixture();
      final writes = <Map<String, dynamic>>[];
      auth.dataRequest = (request) async {
        writes.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _jsonResponse(request, {});
      };
      final repo = _PolicyRepository(auth.client);
      final valid = '😀' * 2000;
      await repo.sendMessage(_peer, valid);
      expect(writes.single['body'], valid);
      expect(writes.single['sender_id'], _ownerA);
      await expectLater(
        repo.sendMessage(_peer, '😀' * 2001),
        throwsArgumentError,
      );
      expect(writes, hasLength(1));
    },
  );
  test(
    'message latest query is bounded and tie ordered, while returned transcript is chronological',
    () async {
      final auth = fixture();
      late Uri uri;
      final newer = '66666666-6666-4666-8666-666666666666';
      auth.dataRequest = (request) async {
        uri = request.url;
        return _jsonResponse(request, [
          _messageJson(id: newer),
          _messageJson(),
        ]);
      };
      final rows = await CommunityRepository(auth.client).loadMessages(_peer);
      expect(uri.queryParameters['limit'], '50');
      expect(
        uri.queryParameters['order'],
        'created_at.desc.nullslast,id.desc.nullslast',
      );
      expect(rows.map((row) => row.id), [_messageId, newer]);
      expect(uri.queryParameters['or'], contains('sender_id.eq.$_ownerA'));
      expect(uri.queryParameters['or'], contains('recipient_id.eq.$_ownerA'));
    },
  );
  test(
    'older page carries time and UUID cursor in each conversation direction',
    () async {
      final auth = fixture();
      late Uri uri;
      auth.dataRequest = (request) async {
        uri = request.url;
        return _jsonResponse(request, [_messageJson()]);
      };
      await CommunityRepository(auth.client).loadOlderMessages(
        _peer,
        before: DateTime.utc(2026, 10, 6, 12),
        beforeId: '66666666-6666-4666-8666-666666666666',
      );
      final filter = uri.queryParameters['or']!;
      expect(RegExp('created_at.lt.').allMatches(filter), hasLength(2));
      expect(RegExp('id.lt.').allMatches(filter), hasLength(2));
      expect(uri.queryParameters['limit'], '50');
    },
  );
  test(
    'readback returns exact incoming server-read IDs without promoting null rows',
    () async {
      final auth = fixture();
      final second = '66666666-6666-4666-8666-666666666666';
      late Uri uri;
      auth.dataRequest = (request) async {
        uri = request.url;
        return _jsonResponse(request, [
          _messageJson(readAt: '2026-10-06T12:00:01Z'),
          _messageJson(id: second),
        ]);
      };
      final ids = await CommunityRepository(
        auth.client,
      ).loadReadMessageIds(_peer, [_messageId, second]);
      expect(ids, {_messageId});
      expect(uri.queryParameters['recipient_id'], 'eq.$_ownerA');
      expect(uri.queryParameters['sender_id'], 'eq.$_peer');
      expect(uri.queryParameters['id'], contains(second));
    },
  );
  test(
    'readback rejects another owner or conversation even if ID matches',
    () async {
      final auth = fixture();
      auth.dataRequest = (request) async => _jsonResponse(request, [
        _messageJson(owner: _ownerB, readAt: '2026-10-06T12:00:01Z'),
      ]);
      await expectLater(
        CommunityRepository(
          auth.client,
        ).loadReadMessageIds(_peer, [_messageId]),
        throwsFormatException,
      );
    },
  );
  test(
    'transcript rejects an unrelated peer row rather than mixing private data',
    () async {
      final auth = fixture();
      auth.dataRequest = (request) async =>
          _jsonResponse(request, [_messageJson(peer: _other)]);
      await expectLater(
        CommunityRepository(auth.client).loadMessages(_peer),
        throwsFormatException,
      );
    },
  );
}
