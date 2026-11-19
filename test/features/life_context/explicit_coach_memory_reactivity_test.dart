import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_memory_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_native_command_repository.dart';
import 'package:body_intelligence_log/features/life_context/decision_memory_page.dart';
import 'package:body_intelligence_log/features/life_context/providers/coach_memory_identity_provider.dart';
import 'package:body_intelligence_log/features/life_context/coach_memory_sync_review_panel.dart';
import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../qa_next/feature_splashes_test_support.dart'
    show closeFeatureSplashDatabase;

import 'life_memory_fixture.dart';

void main() {
  for (final language in ['en', 'ar']) {
    lifeMemoryTestWidgets(
      'preloaded empty memory list follows native commit Undo and explicit forget $language',
      (tester) async {
        final f = await pumpLifeMemory(
          tester,
          memory: true,
          language: language,
        );
        final empty = f.t(
          'Nothing is assumed. Tell BIL “remember…” and confirm before it is saved.',
        );
        expect(find.text(empty), findsOneWidget);
        final native = CoachNativeCommandRepository(
          f.database,
          preferences: f.preferences,
        );
        final scope = CoachNativeOwnerScope(
          ownerId: f.database.localOwnerId,
          isCurrent: () => identical(
            f.container.read(preferencesRepositoryProvider),
            f.preferences,
          ),
        );
        const text = 'Synthetic confirmed preference for concise answers';
        Future<CoachNativeCommit> commit(String operation) => f.real(() async {
          final prepared = await native.prepare(
            toolId: 'save_memory',
            operationId: operation,
            arguments: const {'text': text, 'kind': 'preference'},
            scope: scope,
            now: DateTime.now(),
          );
          return native.commit(command: prepared, scope: scope);
        });
        final first = await commit('memory-live-first-$language');
        expect(first.after.memories!.single['text'], text);
        // No provider invalidation, page remount, reload or restart in this test.
        await f.waitFor(() => find.text(text).evaluate().isNotEmpty);
        expect(find.text(empty), findsNothing);
        await f.real(
          () => native.undo(
            operationId: first.operationId,
            toolId: first.toolId,
            argumentsDigest: first.argumentsDigest,
            scope: scope,
          ),
        );
        await f.waitFor(() => find.text(empty).evaluate().isNotEmpty);
        expect(find.text(text), findsNothing);
        await commit('memory-live-second-$language');
        await f.waitFor(() => find.text(text).evaluate().isNotEmpty);
        final tile = find.ancestor(
          of: find.text(text),
          matching: find.byType(ListTile),
        );
        await f.tap(
          find.descendant(of: tile, matching: find.byType(IconButton)),
        );
        await f.tapText('Forget');
        await f.waitFor(() => find.text(empty).evaluate().isNotEmpty);
        expect(find.text(text), findsNothing);
        expect(
          await f.real(
            () => CoachMemoryRepository(preferences: f.preferences).readLocal(),
          ),
          isEmpty,
        );
        final raw = await f.real(
          () => f.preferences.get(CoachMemoryRepository.storageKey),
        );
        expect((jsonDecode(raw!) as List).single['status'], 'deleted');
        expect(tester.takeException(), isNull);
      },
    );
  }

  lifeMemoryTestWidgets(
    'same-key committed local changes refresh facts without promoting expired inferred or deleted rows',
    (tester) async {
      final f = await pumpLifeMemory(tester, memory: true);
      final confirmed = await f.seedExplicit(
        'Synthetic external local memory writer',
      );
      await f.waitFor(
        () => find
            .text('Synthetic external local memory writer')
            .evaluate()
            .isNotEmpty,
      );
      await f.real(
        () => f.preferences.mutate(
          set: {
            CoachMemoryRepository.storageKey: jsonEncode([
              {...confirmed, 'text': 'Synthetic current accepted memory'},
              {
                ...confirmed,
                'id': 'expired-test',
                'text': 'Expired fact stays hidden',
                'expiresAt': '2000-01-01T00:00:00Z',
              },
              {
                ...confirmed,
                'id': 'inferred-test',
                'text': 'Inferred fact stays hidden',
                'status': 'inferred',
                'source': 'coach_inference',
              },
              {
                ...confirmed,
                'id': 'deleted-test',
                'text': 'Deleted fact stays hidden',
                'status': 'deleted',
              },
            ]),
          },
        ),
      );
      await f.waitFor(
        () => find
            .text('Synthetic current accepted memory')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('Synthetic external local memory writer'), findsNothing);
      expect(find.text('Expired fact stays hidden'), findsNothing);
      expect(find.text('Inferred fact stays hidden'), findsNothing);
      expect(find.text('Deleted fact stays hidden'), findsNothing);
      // Same-key removal is another valid local change; no explicit UI invalidation.
      await f.real(
        () => f.preferences.remove(CoachMemoryRepository.storageKey),
      );
      await f.waitFor(
        () => find.text('Synthetic current accepted memory').evaluate().isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed list hides mismatched owners and retires A B A namespace subscriptions',
    (tester) async {
      late final AppDatabase a, b;
      late final PreferencesRepository pa, pb;
      await runLifeMemoryActionWithFrames(tester, () async {
        a = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'memory-owner-a',
        );
        b = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'memory-owner-b',
        );
        pa = PreferencesRepository(a);
        pb = PreferencesRepository(b);
        await CoachMemoryRepository(
          preferences: pa,
        ).saveConfirmed(text: 'Owned A confirmed fact');
        await CoachMemoryRepository(
          preferences: pb,
        ).saveConfirmed(text: 'Owned B confirmed fact');
      });
      final identities = StreamController<ProfileAuthIdentity>.broadcast(
        sync: true,
      );
      final authOverride = profileAuthIdentityProvider.overrideWith((
        ref,
      ) async* {
        yield const ProfileAuthIdentity(ownerId: 'memory-owner-a', email: null);
        yield* identities.stream;
      });
      final memoryIdentityOverride = coachMemoryIdentityProvider.overrideWith((
        ref,
      ) async* {
        yield const ProfileAuthIdentity(ownerId: 'memory-owner-a', email: null);
        yield* identities.stream;
      });
      final issuesOverride = coachMemorySyncIssuesProvider.overrideWith(
        (ref) async => [],
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(a),
          preferencesRepositoryProvider.overrideWithValue(pa),
          authOverride,
          memoryIdentityOverride,
          issuesOverride,
        ],
      );
      void useNamespace(
        AppDatabase database,
        PreferencesRepository preferences,
      ) {
        container.updateOverrides([
          databaseProvider.overrideWithValue(database),
          preferencesRepositoryProvider.overrideWithValue(preferences),
          authOverride,
          memoryIdentityOverride,
          issuesOverride,
        ]);
      }

      final router = GoRouter(
        initialLocation: '/memory',
        routes: [
          GoRoute(
            path: '/memory',
            builder: (_, _) => const DecisionMemoryPage(),
          ),
        ],
      );
      try {
        await tester.pumpWidget(
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
        await _wait(
          tester,
          () => find.text('Owned A confirmed fact').evaluate().isNotEmpty,
        );
        identities.add(
          const ProfileAuthIdentity(ownerId: 'memory-owner-b', email: null),
        );
        await _wait(
          tester,
          () =>
              find.text('Could not load Coach memories.').evaluate().isNotEmpty,
        );
        expect(find.text('Owned A confirmed fact'), findsNothing);
        useNamespace(b, pb);
        await _wait(
          tester,
          () => find.text('Owned B confirmed fact').evaluate().isNotEmpty,
        );
        await runLifeMemoryActionWithFrames(
          tester,
          () => CoachMemoryRepository(
            preferences: pa,
          ).saveConfirmed(text: 'Late A namespace mutation'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Late A namespace mutation'), findsNothing);
        expect(find.text('Owned B confirmed fact'), findsOneWidget);
        identities.add(
          const ProfileAuthIdentity(ownerId: 'memory-owner-a', email: null),
        );
        await _wait(
          tester,
          () =>
              find.text('Could not load Coach memories.').evaluate().isNotEmpty,
        );
        expect(find.text('Owned B confirmed fact'), findsNothing);
        useNamespace(a, pa);
        await _wait(
          tester,
          () => find.text('Late A namespace mutation').evaluate().isNotEmpty,
        );
        expect(find.text('Owned A confirmed fact'), findsOneWidget);
        expect(find.text('Owned B confirmed fact'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        router.dispose();
        container.dispose();
        // Drain Drift's due stream-cache removals before close iterates them.
        await tester.pump(Duration.zero);
        await runLifeMemoryActionWithFrames(tester, identities.close);
        await tester.pump(Duration.zero);
        await closeFeatureSplashDatabase(tester, a);
        await closeFeatureSplashDatabase(tester, b);
      }
    },
  );
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  final clock = Stopwatch()..start();
  while (!ready() && clock.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(ready(), isTrue);
}
