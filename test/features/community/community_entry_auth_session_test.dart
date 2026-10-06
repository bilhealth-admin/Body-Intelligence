import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_entry_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _codeValue = 'aabbccddaabbccddaabbccddaabbccdd';

class _AuthFixture {
  String owner = _ownerA;
  final sessions = <String, String>{};
  late final client = SupabaseClient(
    'https://entry-auth.invalid',
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

CommunityProfile _profile(String owner, {String name = 'Saved member'}) =>
    CommunityProfile(
      userId: owner,
      displayName: name,
      localeCode: 'en',
      discoverable: false,
      visibility: CommunityProfileVisibility.private,
      allowFriendRequests: false,
      allowFollows: false,
      allowMessagesFrom: CommunityMessagePermission.nobody,
    );

CommunityPublicCode _code() => CommunityPublicCode(
  code: _codeValue,
  uri: Uri.parse('bil://community/member/$_codeValue'),
  handle: 'member_qa',
);

class _EntryRepository extends CommunityRepository {
  _EntryRepository(super.client);

  final profiles = <String, CommunityProfile>{};
  final reads = <String>[];
  final writes = <({String owner, String name, String locale})>[];
  final codes = <String>[];
  final trace = <String>[];
  Completer<CommunityProfile?>? nextRead;
  Completer<void>? nextCreate;
  Completer<CommunityPublicCode>? nextCode;

  @override
  Future<CommunityProfile?> loadMyProfile() async {
    final owner = currentUserId;
    reads.add(owner);
    trace.add('profile');
    final pending = nextRead;
    nextRead = null;
    if (pending != null) return pending.future;
    return profiles[owner];
  }

  @override
  Future<void> createMyCommunityEntryProfile({
    required String displayName,
    required String localeCode,
    required String expectedOwnerId,
  }) async {
    if (currentUserId != expectedOwnerId) {
      throw const AuthException('The original entry owner changed');
    }
    writes.add((owner: expectedOwnerId, name: displayName, locale: localeCode));
    trace.add('create');
    final pending = nextCreate;
    nextCreate = null;
    if (pending != null) await pending.future;
    // Model an already-issued server insert committing for its original owner.
    // Session cancellation must stop later client effects, not undo that insert.
    profiles.putIfAbsent(
      expectedOwnerId,
      () => _profile(expectedOwnerId, name: displayName),
    );
  }

  @override
  Future<CommunityPublicCode> loadPublicCode() async {
    codes.add(currentUserId);
    trace.add('code');
    final pending = nextCode;
    nextCode = null;
    if (pending != null) return pending.future;
    return _code();
  }
}

void _entryTest(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

Future<void> _mount(
  WidgetTester tester,
  _EntryRepository repository, {
  required Future<bool> Function() syncPhoto,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/community',
    routes: [
      GoRoute(
        path: '/community',
        builder: (_, _) => CommunityEntryGate(
          repository: repository,
          syncPhoto: syncPhoto,
          child: const Scaffold(body: Text('Member destination')),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Dashboard')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pump();
}

Finder get _nameField => find.byKey(const Key('community-entry-name'));
Finder get _destination => find.text('Member destination');
String _name(WidgetTester tester) =>
    tester.widget<TextField>(_nameField).controller!.text;

Future<void> _save(WidgetTester tester, String name) async {
  await tester.ensureVisible(_nameField);
  await tester.pumpAndSettle();
  await tester.enterText(_nameField, name);
  final save = find.byKey(const Key('community-entry-save'));
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  expect(save.hitTestable(), findsOneWidget);
  await tester.tap(save);
  await tester.pump();
}

Future<void> _roundTrip(WidgetTester tester, _AuthFixture auth) async {
  final delivered = <({String? eventOwner, String? currentOwner})>[];
  final observation = auth.client.auth.onAuthStateChange.listen((state) {
    delivered.add((
      eventOwner: state.session?.user.id,
      currentOwner: auth.client.auth.currentUser?.id,
    ));
  }, onError: (Object _, StackTrace _) {});
  // Stream cancellation may return a root-zone Future. Dispose this observer
  // in the outer runner so it cannot strand the next fake-clock pump.
  addTearDown(observation.cancel);
  await tester.pump();
  delivered.clear();
  // Unexpired cached recovery is in-memory; the client's worker stays outside
  // fake time while these auth events and gate timeout timers share its clock.
  await auth.roundTrip();
  await tester.pump();
  expect(
    delivered.map((event) => event.eventOwner),
    containsAllInOrder([_ownerB, _ownerA]),
  );
  expect(delivered, contains((eventOwner: _ownerB, currentOwner: _ownerA)));
}

void main() {
  late _AuthFixture auth;
  late _EntryRepository repository;
  late List<String> photoOwners;
  Future<bool> syncPhoto() async {
    photoOwners.add(repository.currentUserId);
    repository.trace.add('photo');
    return true;
  }

  // Create and dispose Supabase's JSON worker in the real runner zone.
  setUp(() async {
    auth = _AuthFixture();
    await auth.signIn(_ownerB);
    await auth.signIn(_ownerA);
    repository = _EntryRepository(auth.client);
    photoOwners = [];
  });
  tearDown(() async {
    await auth.client.dispose();
  });

  _entryTest('queued real A-B-A cancels an old profile check before code', (
    tester,
  ) async {
    final pending = Completer<CommunityProfile?>();
    repository.nextRead = pending;
    await _mount(tester, repository, syncPhoto: syncPhoto);
    expect(repository.reads, [_ownerA]);
    await _roundTrip(tester, auth);
    pending.complete(_profile(_ownerA));
    await tester.pumpAndSettle();
    expect(repository.codes, isEmpty);
    expect(repository.writes, isEmpty);
    expect(photoOwners, isEmpty);
    expect(_destination, findsNothing);
    expect(_nameField, findsOneWidget);
    expect(_name(tester), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final change in ['queued A-B-A', 'other owner', 'logout']) {
    _entryTest('$change cancels pending save read before create/code/photo', (
      tester,
    ) async {
      await _mount(tester, repository, syncPhoto: syncPhoto);
      await tester.pumpAndSettle();
      final pending = Completer<CommunityProfile?>();
      repository.nextRead = pending;
      await _save(tester, 'Old private name');
      expect(repository.writes, isEmpty);
      if (change == 'queued A-B-A') {
        await _roundTrip(tester, auth);
      } else if (change == 'other owner') {
        await tester.runAsync(() => auth.signIn(_ownerB));
        await tester.pump();
      } else {
        await tester.runAsync(
          () => auth.client.auth.signOut(scope: SignOutScope.local),
        );
        await tester.pump();
      }
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(repository.writes, isEmpty);
      expect(repository.profiles, isEmpty);
      expect(repository.codes, isEmpty);
      expect(photoOwners, isEmpty);
      expect(_destination, findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      if (change == 'logout') {
        expect(_nameField, findsNothing);
        expect(find.text('Sign in'), findsOneWidget);
      } else {
        expect(_nameField, findsOneWidget);
        expect(_name(tester), isEmpty);
      }
      expect(tester.takeException(), isNull);
    });
  }

  _entryTest('queued auth cancels follow-up reads after an in-flight insert', (
    tester,
  ) async {
    await _mount(tester, repository, syncPhoto: syncPhoto);
    await tester.pumpAndSettle();
    final pending = Completer<void>();
    repository.nextCreate = pending;
    await _save(tester, 'Original name');
    expect(repository.writes, [
      (owner: _ownerA, name: 'Original name', locale: 'en'),
    ]);
    await _roundTrip(tester, auth);
    final reads = repository.reads.length;
    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.profiles[_ownerA]?.displayName, 'Original name');
    expect(repository.reads, hasLength(reads));
    expect(repository.codes, isEmpty);
    expect(photoOwners, isEmpty);
    expect(_destination, findsNothing);
    expect(_name(tester), isEmpty);
    expect(tester.takeException(), isNull);
  });

  _entryTest('late old save code cannot start optional photo in a new visit', (
    tester,
  ) async {
    await _mount(tester, repository, syncPhoto: syncPhoto);
    await tester.pumpAndSettle();
    final pending = Completer<CommunityPublicCode>();
    repository.nextCode = pending;
    await _save(tester, 'Saved name');
    expect(repository.codes, [_ownerA]);
    expect(photoOwners, isEmpty);
    await _roundTrip(tester, auth);
    await tester.pumpAndSettle();
    // The new visit independently confirms the already-persisted profile/code.
    expect(_destination, findsOneWidget);
    final codes = repository.codes.length;
    pending.complete(_code());
    await tester.pumpAndSettle();
    expect(repository.codes, hasLength(codes));
    expect(repository.writes, hasLength(1));
    expect(photoOwners, isEmpty);
    expect(_destination, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _entryTest('old optional photo failure stays silent after queued auth', (
    tester,
  ) async {
    final photo = Completer<bool>();
    await _mount(
      tester,
      repository,
      syncPhoto: () {
        photoOwners.add(repository.currentUserId);
        return photo.future;
      },
    );
    await tester.pumpAndSettle();
    await _save(tester, 'Saved member');
    await tester.pumpAndSettle();
    expect(_destination, findsOneWidget);
    expect(photoOwners, [_ownerA]);
    await _roundTrip(tester, auth);
    await tester.pumpAndSettle();
    photo.complete(false);
    await tester.pumpAndSettle();
    expect(_destination, findsOneWidget);
    expect(repository.writes, hasLength(1));
    expect(photoOwners, [_ownerA]);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _entryTest('same-owner token refresh preserves the entered private name', (
    tester,
  ) async {
    await _mount(tester, repository, syncPhoto: syncPhoto);
    await tester.pumpAndSettle();
    await tester.enterText(_nameField, 'My preserved name');
    final reads = repository.reads.length;
    await tester.runAsync(() => auth.client.auth.refreshSession());
    await tester.pumpAndSettle();
    expect(_name(tester), 'My preserved name');
    expect(repository.reads, hasLength(reads));
    expect(repository.writes, isEmpty);
    expect(repository.codes, isEmpty);
    expect(photoOwners, isEmpty);
    expect(_destination, findsNothing);
    expect(tester.takeException(), isNull);
  });

  _entryTest('normal first save still confirms profile and code before photo', (
    tester,
  ) async {
    await _mount(tester, repository, syncPhoto: syncPhoto);
    await tester.pumpAndSettle();
    expect(_destination, findsNothing);
    await _save(tester, '  New member  ');
    await tester.pumpAndSettle();
    expect(repository.writes, [
      (owner: _ownerA, name: 'New member', locale: 'en'),
    ]);
    expect(repository.profiles[_ownerA]?.displayName, 'New member');
    expect(repository.codes, [_ownerA]);
    expect(repository.trace, [
      'profile',
      'profile',
      'create',
      'profile',
      'code',
      'photo',
    ]);
    expect(photoOwners, [_ownerA]);
    expect(_destination, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
