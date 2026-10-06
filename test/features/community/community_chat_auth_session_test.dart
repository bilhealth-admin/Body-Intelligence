import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'community_chat_repository_cases.dart';
part 'community_message_entry_owner_cases.dart';
part 'community_message_retry_cases.dart';
part 'community_chat_visibility_paging_cases.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _peer = '33333333-3333-4333-8333-333333333333';
const _other = '44444444-4444-4444-8444-444444444444';
const _secondId = '66666666-6666-4666-8666-666666666666';
const _messageId = '55555555-5555-4555-8555-555555555555';

class _AuthFixture {
  String owner = _ownerA;
  Future<http.Response> Function(http.Request)? dataRequest;
  final sessions = <String, String>{};
  late final client = SupabaseClient(
    'https://entry-auth.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(
      MockClient((request) async {
        Object body;
        if (request.url.path == '/auth/v1/token') {
          final payload = base64Url
              .encode(
                utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})),
              )
              .replaceAll('=', '');
          body = {
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': owner,
              'email': 'entry-fixture@example.invalid',
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-10-06T00:00:00Z',
            },
          };
        } else if (request.url.path == '/auth/v1/logout') {
          body = {};
        } else {
          final handler = dataRequest;
          if (handler != null) return handler(request);
          throw StateError('Unexpected external request: ${request.url.path}');
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    ),
  );

  Future<void> signIn(String nextOwner) async {
    owner = nextOwner;
    await client.auth.signInWithPassword(
      email: 'entry-fixture@example.invalid',
      password: 'synthetic-password',
    );
    sessions[owner] = jsonEncode(client.auth.currentSession!.toJson());
  }

  Future<void> roundTrip() async {
    // Public GoTrue recovery applies both sessions before its queued auth
    // listeners run. The B event must still invalidate earlier A operations.
    final second = client.auth.recoverSession(sessions[_ownerB]!);
    final first = client.auth.recoverSession(sessions[_ownerA]!);
    await Future.wait([second, first]);
  }
}

CommunityMessage _message({
  String id = _messageId,
  String peer = _peer,
  String body = 'Private A transcript',
}) => CommunityMessage(
  id: id,
  senderId: peer,
  recipientId: _ownerA,
  body: body,
  createdAt: DateTime.utc(2026, 10, 6, 12),
);

class _Repository extends CommunityRepository {
  _Repository(super.client);
  final changes = StreamController<void>.broadcast();
  final reads = <List<String>>[];
  final loads = <String>[];
  final sends = <String>[];
  List<CommunityMessage> rows = [_message()];
  Completer<List<CommunityMessage>>? pendingLoad;
  Completer<void>? pendingSend;
  Completer<int>? pendingRead;
  int readbacks = 0;
  final olderCursors = <String>[];
  bool failOlder = false;
  List<CommunityMessage> olderRows = [];
  bool failRead = false;
  Set<String> confirmed = {_messageId};
  @override
  Stream<void> watchConversationChanges(String id) => changes.stream;
  @override
  Future<List<CommunityMessage>> loadMessages(String id) async {
    loads.add(id);
    final pending = pendingLoad;
    pendingLoad = null;
    return pending == null ? List.of(rows) : pending.future;
  }

  @override
  Future<int> markVisibleMessagesRead(List<String> ids) async {
    reads.add(List.of(ids));
    if (failRead) throw StateError('offline');
    return pendingRead?.future ?? confirmed.length;
  }

  @override
  Future<Set<String>> loadReadMessageIds(String peer, List<String> ids) async {
    readbacks++;
    return confirmed.intersection(ids.toSet());
  }

  @override
  Future<List<CommunityMessage>> loadOlderMessages(
    String peer, {
    required DateTime before,
    required String beforeId,
  }) async {
    olderCursors.add(beforeId);
    if (failOlder) throw StateError('offline');
    return olderRows;
  }

  @override
  Future<void> sendMessage(String id, String body) async {
    sends.add(body);
    await pendingSend?.future;
  }
}

void _lifecycle(WidgetTester tester, {required bool resumed}) {
  final current = tester.binding.lifecycleState;
  final states = resumed
      ? (current == AppLifecycleState.paused
            ? [
                AppLifecycleState.hidden,
                AppLifecycleState.inactive,
                AppLifecycleState.resumed,
              ]
            : [AppLifecycleState.inactive, AppLifecycleState.resumed])
      : [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ];
  if (resumed && current == AppLifecycleState.resumed) return;
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _case(String name, WidgetTesterCallback test) =>
    testWidgets(name, (tester) async {
      try {
        await test(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
Widget _app(_Repository repo, {String peer = _peer}) => MaterialApp(
  home: CommunityChatPage(
    key: const ValueKey('same-chat'),
    userId: peer,
    displayName: 'Private chat',
    repository: repo,
  ),
);
Finder get _composer => find.byKey(const Key('community-message-composer'));
Finder get _send => find.widgetWithIcon(IconButton, Icons.send_rounded);
Future<void> _mount(
  WidgetTester tester,
  _Repository repo, {
  String peer = _peer,
}) async {
  await tester.pumpWidget(_app(repo, peer: peer));
  await tester.pump();
  await tester.pump();
}

void main() {
  late _AuthFixture auth;
  late _Repository repo;
  late List<_Repository> repositories;
  setUp(() async {
    auth = _AuthFixture();
    await auth.signIn(_ownerB);
    await auth.signIn(_ownerA);
    repo = _Repository(auth.client);
    repositories = [repo];
  });
  tearDown(() async {
    for (final r in repositories) {
      await r.changes.close();
    }
    await auth.client.dispose();
  });
  _repositoryCases(() => auth);
  _messageEntryCases(() => auth, (repo) => repositories.add(repo));
  _messageRetryCases(() => auth, (repo) => repositories.add(repo));
  _visibilityPagingCases(() => auth, () => repo);
  for (final aba in [false, true]) {
    _case(
      'private transcript and draft retire on real ${aba ? 'queued A-B-A' : 'A-B'}',
      (tester) async {
        await _mount(tester, repo);
        await tester.enterText(_composer, 'Private draft');
        expect(find.text('Private A transcript'), findsOneWidget);
        if (aba) {
          await auth.roundTrip();
        } else {
          await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
        }
        await tester.pumpAndSettle();
        expect(find.text('Private A transcript'), findsNothing);
        expect(find.text('Private draft'), findsNothing);
        expect(_composer, findsNothing);
        expect(repo.sends, isEmpty);
      },
    );
    _case(
      'pending transcript cannot paint after real ${aba ? 'queued A-B-A' : 'A-B'}',
      (tester) async {
        final pending = Completer<List<CommunityMessage>>();
        repo.pendingLoad = pending;
        await _mount(tester, repo);
        if (aba) {
          await auth.roundTrip();
        } else {
          await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
        }
        await tester.pump();
        pending.complete([_message()]);
        await tester.pumpAndSettle();
        expect(find.text('Private A transcript'), findsNothing);
        expect(repo.reads, isEmpty);
        expect(_composer, findsNothing);
      },
    );
  }
  for (final replacement in ['peer', 'repository']) {
    _case(
      '$replacement replacement clears private draft and rejects late load',
      (tester) async {
        final pending = Completer<List<CommunityMessage>>();
        repo.pendingLoad = pending;
        await _mount(tester, repo);
        await tester.enterText(_composer, 'Old scope draft');
        final next = replacement == 'repository'
            ? _Repository(auth.client)
            : repo;
        if (!identical(next, repo)) repositories.add(next);
        next.rows = [_message(peer: _other, body: 'New scope transcript')];
        await _mount(
          tester,
          next,
          peer: replacement == 'peer' ? _other : _peer,
        );
        pending.complete([_message()]);
        await tester.pumpAndSettle();
        expect(find.text('Private A transcript'), findsNothing);
        expect(find.text('New scope transcript'), findsOneWidget);
        expect(tester.widget<TextField>(_composer).controller!.text, isEmpty);
      },
    );
  }
  _case('same-owner refresh retains input and visible private transcript', (
    tester,
  ) async {
    await _mount(tester, repo);
    await tester.enterText(_composer, 'Keep my draft');
    await auth.client.auth.recoverSession(auth.sessions[_ownerA]!);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_composer).controller!.text,
      'Keep my draft',
    );
    expect(find.text('Private A transcript'), findsOneWidget);
  });
  _case('same-text edit during send is a new draft revision', (tester) async {
    repo.pendingSend = Completer<void>();
    await _mount(tester, repo);
    await tester.enterText(_composer, 'Send this');
    await tester.tap(_send);
    await tester.pump();
    await tester.enterText(_composer, 'Changed');
    await tester.enterText(_composer, 'Send this');
    repo.pendingSend!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_composer).controller!.text, 'Send this');
  });
  _case('fetch and first 599ms are not read receipts', (tester) async {
    await _mount(tester, repo);
    await tester.pump(const Duration(milliseconds: 599));
    expect(repo.reads, isEmpty);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(repo.reads, [_messageId].map((id) => [id]).toList());
  });
  _case('background dwell is discarded until resumed', (tester) async {
    await _mount(tester, repo);
    await tester.pump(const Duration(milliseconds: 250));
    _lifecycle(tester, resumed: false);
    await tester.pump(const Duration(seconds: 2));
    expect(repo.reads, isEmpty);
    _lifecycle(tester, resumed: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 599));
    expect(repo.reads, isEmpty);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(repo.reads, hasLength(1));
  });
  _case('failed read does not retry on rebuild or realtime', (tester) async {
    repo.failRead = true;
    await _mount(tester, repo);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(repo.reads, hasLength(1));
    repo.changes.add(null);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(repo.reads, hasLength(1));
  });
  _case('overflow remains intact and cannot be sent', (tester) async {
    await _mount(tester, repo);
    final text = 'a' * 2001;
    await tester.enterText(_composer, text);
    await tester.tap(_send);
    await tester.pump();
    expect(tester.widget<TextField>(_composer).controller!.text, text);
    expect(repo.sends, isEmpty);
  });
}
