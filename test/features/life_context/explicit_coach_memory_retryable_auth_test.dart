import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_memory_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_native_command_repository.dart';
import 'package:body_intelligence_log/features/life_context/coach_memory_sync_review_panel.dart';
import 'package:body_intelligence_log/features/life_context/decision_memory_page.dart';
import 'package:body_intelligence_log/features/life_context/providers/coach_memory_identity_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../qa_next/feature_splashes_test_support.dart'
    show closeFeatureSplashDatabase;

import 'life_memory_fixture.dart' show runLifeMemoryActionWithFrames;

void main() {
  testWidgets(
    'typed retryable same-owner Auth failure leaves local memory reactive',
    (tester) async {
      final auth = _MemoryAuth('memory-auth-owner');
      final f = await _MemoryPage.create(
        tester,
        owner: 'memory-auth-owner',
        auth: auth,
      );
      try {
        await f.mount();
        await _wait(
          tester,
          () => find.text(_originalFact).evaluate().isNotEmpty,
        );
        final session = auth.currentSession;
        auth.fail(AuthRetryableFetchException(statusCode: '503'));
        await tester.pumpAndSettle();
        expect(identical(auth.currentSession, session), isTrue);
        expect(find.text(_originalFact), findsOneWidget);
        expect(find.text(_loadFailure), findsNothing);
        await f.nativeSave();
        await _wait(tester, () => find.text(_newFact).evaluate().isNotEmpty);
        expect(find.text(_originalFact), findsOneWidget);
        expect(f.container.read(coachMemoryIdentityProvider).hasError, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose();
      }
    },
  );

  testWidgets(
    'local guest memory works without SDK and retains only typed same-guest transport failure',
    (tester) async {
      final f = await _MemoryPage.create(tester, owner: null, auth: null);
      final auth = _MemoryAuth(null);
      try {
        await f.mount();
        await _wait(
          tester,
          () => find.text(_originalFact).evaluate().isNotEmpty,
        );
        f.useAuth(auth);
        await _wait(
          tester,
          () =>
              auth.changes.hasListener &&
              !f.container.read(coachMemoryIdentityProvider).isLoading &&
              f.container.read(coachMemoryIdentityProvider).asData != null &&
              find.text(_originalFact).evaluate().isNotEmpty,
        );
        auth.fail(AuthRetryableFetchException(statusCode: '503'));
        await tester.pumpAndSettle();
        expect(find.text(_originalFact), findsOneWidget);
        await f.nativeSave();
        await _wait(tester, () => find.text(_newFact).evaluate().isNotEmpty);
        auth.fail(AuthRetryableFetchException(statusCode: '401'));
        await _wait(
          tester,
          () => find.text(_loadFailure).evaluate().isNotEmpty,
        );
        expect(find.text(_originalFact), findsNothing);
        auth.fail(AuthRetryableFetchException(statusCode: '503'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text(_originalFact), findsNothing);
        expect(f.container.read(coachMemoryIdentityProvider).hasError, isTrue);
        // Only a real new auth event may establish the guest lifetime again.
        auth.owner(null);
        await _wait(tester, () => find.text(_newFact).evaluate().isNotEmpty);
        auth.owner('memory-auth-owner');
        await _wait(
          tester,
          () => find.text(_loadFailure).evaluate().isNotEmpty,
        );
        expect(find.text(_newFact), findsNothing);
        auth.owner(null);
        await _wait(tester, () => find.text(_newFact).evaluate().isNotEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose();
      }
    },
  );

  for (final error in [
    AuthRetryableFetchException(statusCode: '403'),
    StateError('synthetic non-transport failure'),
  ]) {
    test(
      'local memory identity does not auto-reseed after ${error.runtimeType}',
      () async {
        final auth = _MemoryAuth('memory-auth-owner');
        final container = ProviderContainer(
          overrides: [coachMemoryAuthClientProvider.overrideWithValue(auth)],
        );
        final failed = Completer<void>();
        final recovered = Completer<void>();
        final sub = container.listen(coachMemoryIdentityProvider, (_, next) {
          if (next.hasError && !failed.isCompleted) failed.complete();
          if (failed.isCompleted &&
              next.asData?.value.ownerId == 'memory-auth-owner' &&
              !recovered.isCompleted) {
            recovered.complete();
          }
        });
        try {
          expect(
            (await container.read(coachMemoryIdentityProvider.future)).ownerId,
            'memory-auth-owner',
          );
          auth.fail(error);
          await failed.future.timeout(const Duration(seconds: 2));
          auth.fail(AuthRetryableFetchException(statusCode: '503'));
          // More than Riverpod's initial default retry delay: no reseed opt-out
          // in this container; the memory identity provider itself must fence it.
          await Future<void>.delayed(const Duration(milliseconds: 350));
          expect(container.read(coachMemoryIdentityProvider).hasError, isTrue);
          expect(auth.currentUser!.id, 'memory-auth-owner');
          auth.owner('memory-auth-owner');
          await recovered.future.timeout(const Duration(seconds: 2));
          expect(container.read(coachMemoryIdentityProvider).hasError, isFalse);
        } finally {
          sub.close();
          container.dispose();
          await auth.changes.close();
        }
      },
    );
  }

  testWidgets(
    'sign-out and missing-session typed failure never retain the old owner facts',
    (tester) async {
      final auth = _MemoryAuth('memory-auth-owner');
      final f = await _MemoryPage.create(
        tester,
        owner: 'memory-auth-owner',
        auth: auth,
      );
      try {
        await f.mount();
        await _wait(
          tester,
          () => find.text(_originalFact).evaluate().isNotEmpty,
        );
        auth.owner(null);
        await _wait(
          tester,
          () => find.text(_loadFailure).evaluate().isNotEmpty,
        );
        auth.fail(AuthRetryableFetchException(statusCode: '503'));
        await tester.pumpAndSettle();
        expect(find.text(_originalFact), findsNothing);
        auth.owner('memory-auth-owner');
        await _wait(
          tester,
          () => find.text(_originalFact).evaluate().isNotEmpty,
        );
        auth.session =
            null; // No authoritative event: a typed error is not proof.
        auth.fail(AuthRetryableFetchException(statusCode: '503'));
        await _wait(
          tester,
          () => find.text(_loadFailure).evaluate().isNotEmpty,
        );
        expect(find.text(_originalFact), findsNothing);
        auth.session = _MemoryAuth.sessionFor('memory-auth-owner');
        auth.fail(AuthRetryableFetchException(statusCode: '503'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text(_originalFact), findsNothing);
        expect(f.container.read(coachMemoryIdentityProvider).hasError, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose();
      }
    },
  );
}

const _originalFact = 'Synthetic already confirmed local memory';
const _newFact = 'Synthetic memory after typed network failure';
const _loadFailure = 'Could not load Coach memories.';

class _MemoryAuth extends Fake implements GoTrueClient {
  _MemoryAuth(String? owner) {
    session = owner == null ? null : sessionFor(owner);
  }
  final changes = StreamController<AuthState>.broadcast(sync: true);
  Session? session;
  static Session sessionFor(String owner) => Session(
    accessToken: 'public-synthetic-token',
    tokenType: 'bearer',
    refreshToken: 'public-synthetic-refresh',
    user: User(
      id: owner,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );
  @override
  Session? get currentSession => session;
  @override
  User? get currentUser => session?.user;
  @override
  Stream<AuthState> get onAuthStateChange => changes.stream;
  void owner(String? value) {
    session = value == null ? null : sessionFor(value);
    changes.add(
      AuthState(
        value == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn,
        session,
      ),
    );
  }

  void fail(Object error) => changes.addError(error, StackTrace.current);
}

class _MemoryPage {
  _MemoryPage(this.tester, this.database, this.preferences, _MemoryAuth? auth)
    : _auth = auth {
    if (auth != null) _clients.add(auth);
    _legacyIdentity = profileAuthIdentityProvider.overrideWith((ref) async* {
      final current = ref.watch(coachMemoryAuthClientProvider);
      if (current == null) {
        yield const ProfileAuthIdentity.local();
        return;
      }
      yield ProfileAuthIdentity.fromUser(current.currentUser);
      await for (final state in current.onAuthStateChange) {
        yield ProfileAuthIdentity.fromUser(state.session?.user);
      }
    });
    _issues = coachMemorySyncIssuesProvider.overrideWith((ref) async => []);
    container = ProviderContainer(overrides: _overrides());
    router = GoRouter(
      initialLocation: '/memory',
      routes: [
        GoRoute(path: '/memory', builder: (_, _) => const DecisionMemoryPage()),
      ],
    );
  }
  final WidgetTester tester;
  final AppDatabase database;
  final PreferencesRepository preferences;
  final _clients = <_MemoryAuth>{};
  _MemoryAuth? _auth;
  late final ProviderContainer container;
  late final GoRouter router;
  late final Override _legacyIdentity, _issues;
  // The old profile identity override exists only to reproduce V1's actual
  // async* error forwarding before the page switches to the scoped provider.
  List<Override> _overrides() => [
    databaseProvider.overrideWithValue(database),
    preferencesRepositoryProvider.overrideWithValue(preferences),
    coachMemoryAuthClientProvider.overrideWithValue(_auth),
    _legacyIdentity,
    _issues,
  ];
  void useAuth(_MemoryAuth auth) {
    _clients.add(auth);
    _auth = auth;
    container.updateOverrides(_overrides());
  }

  static Future<_MemoryPage> create(
    WidgetTester tester, {
    required String? owner,
    required _MemoryAuth? auth,
  }) async {
    final db = await runLifeMemoryActionWithFrames(tester, () async {
      final value = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      // Construct and first-open in the same real zone; seed once before mount.
      await value.customSelect('SELECT 1').getSingle();
      await CoachMemoryRepository(
        preferences: PreferencesRepository(value),
      ).saveConfirmed(text: _originalFact);
      return value;
    });
    return _MemoryPage(tester, db, PreferencesRepository(db), auth);
  }

  Future<void> mount() => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
      ),
    ),
  );
  Future<void> nativeSave() async {
    await runLifeMemoryActionWithFrames(tester, () async {
      final native = CoachNativeCommandRepository(
        database,
        preferences: preferences,
      );
      final scope = CoachNativeOwnerScope(
        ownerId: database.localOwnerId,
        isCurrent: () => true,
      );
      final command = await native.prepare(
        toolId: 'save_memory',
        operationId: 'offline-memory-native',
        arguments: const {'text': _newFact, 'kind': 'preference'},
        scope: scope,
        now: DateTime.now(),
      );
      await native.commit(command: command, scope: scope);
    });
  }

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    container.dispose();
    await tester.pump(Duration.zero);
    await runLifeMemoryActionWithFrames(tester, () async {
      for (final client in _clients) {
        await client.changes.close();
      }
    });
    await tester.pump(Duration.zero);
    await closeFeatureSplashDatabase(tester, database);
  }
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  final watch = Stopwatch()..start();
  while (!ready() && watch.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(ready(), isTrue);
}
