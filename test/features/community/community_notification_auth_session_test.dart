import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _activityA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _activityB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class _AuthFixture {
  String owner = _ownerA;
  final sessions = <String, String>{};
  late final client = SupabaseClient(
    'https://activity-auth.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      Object body;
      if (request.url.path == '/auth/v1/token') {
        final payload = base64Url
            .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
            .replaceAll('=', '');
        body = {
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': owner,
            'email': 'activity-fixture@example.invalid',
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-10-06T00:00:00Z',
          },
        };
      } else if (request.url.path == '/auth/v1/logout') {
        body = {};
      } else {
        throw StateError('Unexpected external request: ${request.url.path}');
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );

  Future<void> signIn(String nextOwner) async {
    owner = nextOwner;
    await client.auth.signInWithPassword(
      email: 'activity-fixture@example.invalid',
      password: 'synthetic-password',
    );
    sessions[owner] = jsonEncode(client.auth.currentSession!.toJson());
  }

  Future<void> roundTrip() async {
    // Real GoTrue session recovery updates currentUser before its asynchronous
    // auth events are delivered. Both events retain their own session owner.
    final second = client.auth.recoverSession(sessions[_ownerB]!);
    final first = client.auth.recoverSession(sessions[_ownerA]!);
    await Future.wait([second, first]);
  }
}

class _ActivityRepository extends CommunityRepository {
  _ActivityRepository(super.client);

  final seen = <String, Set<String>>{};
  final reads = <String>[];
  final attentionReads = <String>[];
  final marks = <({String owner, List<String> ids})>[];
  final collaborations = <String>[];
  Completer<void>? pendingWrite;
  Completer<void>? pendingCollaboration;
  bool collaboration = false;
  int privateReads = 0;
  int friendChanges = 0;

  @override
  Future<CommunityAttention> loadAttention() async {
    final owner = currentUserId;
    attentionReads.add(owner);
    return CommunityAttention(
      communityUpdates: seen[owner]?.isNotEmpty == true ? 0 : 1,
      unreadMessages: 7,
      incomingRequests: 2,
    );
  }

  @override
  Future<List<CommunityNotification>> loadCommunityNotifications({
    DateTime? before,
    String? beforeId,
    List<CommunityNotificationKind>? kinds,
    int limit = 30,
  }) async {
    final owner = currentUserId;
    reads.add(owner);
    final id = owner == _ownerA ? _activityA : _activityB;
    return [
      CommunityNotification(
        id: id,
        kind: collaboration
            ? CommunityNotificationKind.collaborationInvite
            : CommunityNotificationKind.comment,
        actorId: owner == _ownerA ? _ownerB : _ownerA,
        actorDisplayName: owner == _ownerA
            ? 'Account A peer'
            : 'Account B peer',
        createdAt: DateTime.utc(2026, 10, 6),
        entityKind: 'post',
        entityId: '33333333-3333-4333-8333-333333333333',
        copyKey: 'synthetic_activity_v1',
        deepLinkPath: '/community',
        seenAt: seen[owner]?.contains(id) == true
            ? DateTime.utc(2026, 10, 6, 1)
            : null,
      ),
    ];
  }

  @override
  Future<int> markCommunityNotificationsSeen(List<String> ids) async {
    final owner = currentUserId;
    marks.add((owner: owner, ids: List.of(ids)));
    final pending = pendingWrite;
    if (pending != null) await pending.future;
    final confirmed = seen.putIfAbsent(owner, () => {});
    final previous = confirmed.length;
    confirmed.addAll(ids);
    return confirmed.length - previous;
  }

  @override
  Future<CommunityCollaborationStatus> respondCommunityCollaboration({
    required String postId,
    required bool accept,
  }) async {
    collaborations.add(currentUserId);
    await pendingCollaboration?.future;
    return accept
        ? CommunityCollaborationStatus.accepted
        : CommunityCollaborationStatus.declined;
  }

  @override
  Future<void> markConversationRead(String otherUserId) async {
    privateReads++;
    throw StateError('Activity must not read private messages');
  }

  @override
  Future<void> respondToFriendship(String id, {required bool accept}) async {
    friendChanges++;
    throw StateError('Activity must not answer friend requests');
  }
}

void _authTest(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

Future<void> _mount(WidgetTester tester, _ActivityRepository repository) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final router = GoRouter(
    initialLocation: '/community/notifications',
    routes: [
      GoRoute(
        path: '/community/notifications',
        builder: (_, _) => CommunityNotificationsPage(repository: repository),
      ),
      GoRoute(
        path: '/community',
        builder: (_, _) => const Scaffold(body: Text('Community destination')),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Dashboard')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Future<void> _dwell(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pumpAndSettle();
}

void _expectSeen(WidgetTester tester, String id, String expected) {
  final marker = find.byKey(ValueKey('community-activity-read-state-$id'));
  expect(marker, findsOneWidget);
  expect(tester.widget<Semantics>(marker).properties.value, expected);
}

void _expectMarks(
  _ActivityRepository repository,
  List<({String owner, List<String> ids})> expected,
) {
  expect(
    repository.marks.map((mark) => mark.owner),
    expected.map((mark) => mark.owner),
  );
  expect(
    repository.marks.map((mark) => mark.ids),
    expected.map((mark) => mark.ids),
  );
}

void main() {
  late _AuthFixture auth;
  late _ActivityRepository repository;
  // Supabase's JSON worker is constructed and closed in the real runner zone.
  setUp(() async {
    auth = _AuthFixture();
    await auth.signIn(_ownerB);
    await auth.signIn(_ownerA);
    repository = _ActivityRepository(auth.client);
  });
  tearDown(() async {
    await auth.client.dispose();
  });

  _authTest('queued real A-B-A auth events cancel a pending explicit receipt', (
    tester,
  ) async {
    final pending = Completer<void>();
    repository.pendingWrite = pending;
    await _mount(tester, repository);
    await tester.tap(find.textContaining('Account A peer'));
    await tester.pump();
    _expectMarks(repository, [
      (owner: _ownerA, ids: [_activityA]),
    ]);

    final delivered = <({String? eventOwner, String? currentOwner})>[];
    final observation = auth.client.auth.onAuthStateChange.listen((state) {
      delivered.add((
        eventOwner: state.session?.user.id,
        currentOwner: auth.client.auth.currentUser?.id,
      ));
    }, onError: (Object _, StackTrace _) {});
    addTearDown(observation.cancel);
    await tester.pump();
    delivered.clear();
    await tester.runAsync(auth.roundTrip);
    await tester.pumpAndSettle();
    expect(
      delivered.map((event) => event.eventOwner),
      containsAllInOrder([_ownerB, _ownerA]),
    );
    expect(
      delivered,
      contains((eventOwner: _ownerB, currentOwner: _ownerA)),
      reason:
          'The real SDK event owner can differ from currentUser at delivery',
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CommunityNotificationsPage), findsOneWidget);
    expect(find.text('Community destination'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(repository.privateReads, 0);
    expect(repository.friendChanges, 0);
    expect(tester.takeException(), isNull);
  });

  _authTest('queued real A-B-A auth frees dwell from the cancelled write', (
    tester,
  ) async {
    final pending = Completer<void>();
    repository.pendingWrite = pending;
    await _mount(tester, repository);
    await _dwell(tester);
    expect(repository.marks, hasLength(1));
    repository.pendingWrite = null;

    await tester.runAsync(auth.roundTrip);
    await tester.pumpAndSettle();
    _expectSeen(tester, _activityA, 'New');
    await _dwell(tester);
    _expectMarks(repository, [
      (owner: _ownerA, ids: [_activityA]),
      (owner: _ownerA, ids: [_activityA]),
    ]);
    _expectSeen(tester, _activityA, 'Seen');
    final reads = repository.reads.length;
    final attentionReads = repository.attentionReads.length;
    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.reads, hasLength(reads));
    expect(repository.attentionReads, hasLength(attentionReads));
    _expectSeen(tester, _activityA, 'Seen');
    expect(repository.privateReads, 0);
    expect(repository.friendChanges, 0);
    expect(tester.takeException(), isNull);
  });

  _authTest('new auth owner can acknowledge before the old write completes', (
    tester,
  ) async {
    final pending = Completer<void>();
    repository.pendingWrite = pending;
    await _mount(tester, repository);
    await _dwell(tester);
    repository.pendingWrite = null;
    await tester.runAsync(() => auth.signIn(_ownerB));
    await tester.pumpAndSettle();
    expect(find.textContaining('Account A peer'), findsNothing);
    expect(find.textContaining('Account B peer'), findsOneWidget);
    _expectSeen(tester, _activityB, 'New');
    await _dwell(tester);
    _expectMarks(repository, [
      (owner: _ownerA, ids: [_activityA]),
      (owner: _ownerB, ids: [_activityB]),
    ]);
    _expectSeen(tester, _activityB, 'Seen');
    final reads = repository.reads.length;
    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.reads, hasLength(reads));
    _expectSeen(tester, _activityB, 'Seen');
    expect(find.byType(SnackBar), findsNothing);
    expect(repository.privateReads, 0);
    expect(repository.friendChanges, 0);
    expect(tester.takeException(), isNull);
  });

  _authTest('same-owner token refresh preserves a pending explicit receipt', (
    tester,
  ) async {
    final pending = Completer<void>();
    repository.pendingWrite = pending;
    await _mount(tester, repository);
    await tester.tap(find.textContaining('Account A peer'));
    await tester.pump();
    final reads = repository.reads.length;
    await tester.runAsync(() => auth.client.auth.refreshSession());
    await tester.pumpAndSettle();
    expect(repository.reads, hasLength(reads));
    _expectMarks(repository, [
      (owner: _ownerA, ids: [_activityA]),
    ]);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Community destination'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _authTest('logout clears rows and suppresses a late explicit write failure', (
    tester,
  ) async {
    final pending = Completer<void>();
    repository.pendingWrite = pending;
    await _mount(tester, repository);
    await tester.tap(find.textContaining('Account A peer'));
    await tester.pump();
    await tester.runAsync(
      () => auth.client.auth.signOut(scope: SignOutScope.local),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.textContaining('Account A peer'), findsNothing);
    pending.completeError(StateError('Synthetic old account write failure'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.text('Community destination'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(repository.reads, [_ownerA]);
    expect(tester.takeException(), isNull);
  });

  _authTest('queued auth round trip cancels collaboration follow-up effects', (
    tester,
  ) async {
    final pending = Completer<void>();
    repository.collaboration = true;
    repository.pendingCollaboration = pending;
    await _mount(tester, repository);
    await tester.tap(
      find.byKey(const Key('community-collab-accept-$_activityA')),
    );
    await tester.pump();
    expect(repository.collaborations, [_ownerA]);
    // A fresh foreground visit may legitimately acknowledge after dwell. Keep
    // it paused here to isolate effects of the pending explicit response.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await tester.runAsync(auth.roundTrip);
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.marks, isEmpty);
    expect(find.text('Collaboration accepted.'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(CommunityNotificationsPage), findsOneWidget);
    expect(repository.privateReads, 0);
    expect(repository.friendChanges, 0);
    expect(tester.takeException(), isNull);
  });
}
