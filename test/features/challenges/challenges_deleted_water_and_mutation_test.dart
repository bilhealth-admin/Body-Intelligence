import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/challenge_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/challenges/challenges_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'challenges_fixture.dart';

void main() {
  for (final type in ['water', 'consistentLogging', 'return']) {
    test(
      'soft-deleted water does not qualify actual $type progress provider',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            dashboardNutrientGoalProvider(
              'goal.proteinGrams',
            ).overrideWith((_) => Stream<double?>.value(null)),
            dashboardNutrientGoalProvider(
              'goal.fiber',
            ).overrideWith((_) => Stream<double?>.value(null)),
          ],
        );
        try {
          final now = DateTime.now();
          final id = await ChallengeRepository(database).start(
            type: type,
            title: 'Private test',
            targetDays: 1,
            startedAt: DateTime(now.year, now.month, now.day),
          );
          final water = WaterRepository(database);
          final waterId = await water.add(occurredAt: now, amountMl: 2000);
          await water.delete(waterId);
          final actualWaterRow = await database
              .select(database.waterEntries)
              .getSingle();
          expect(actualWaterRow.deletedAt, isNotNull);
          expect(actualWaterRow.syncStatus, 'pendingDelete');
          expect(await water.totalForDay(now), 0);
          final challenge = (await database.select(database.challenges).get())
              .singleWhere((row) => row.id == id);
          final provider = challengeProgressProvider(challenge);
          // Match a real Consumer's watch lifetime. Riverpod pauses a stream
          // with no listeners, so a read of .future alone can stall this probe.
          final subscription = container.listen(
            provider,
            (_, _) {},
            fireImmediately: true,
          );
          try {
            final progress = await container
                .read(provider.future)
                .timeout(const Duration(seconds: 5));
            expect(container.read(provider).hasValue, isTrue);
            expect(progress.qualifyingDays, 0);
            expect(progress.fraction, 0);
            expect(progress.complete, isFalse);
          } finally {
            subscription.close();
          }
        } finally {
          container.dispose();
          await database.close().timeout(const Duration(seconds: 5));
        }
      },
    );
  }

  challengeTestWidgets(
    'deleted water never paints or persists a completed challenge',
    (tester) async {
      final f = await pumpChallenges(
        tester,
        seedChallenge: true,
        deletedWater: true,
      );
      await f.reveal(find.byType(LinearProgressIndicator));
      final bars = tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bars.single.value, 0);
      expect(find.byIcon(Icons.emoji_events), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      expect((await f.rows()).single.status, 'active');
      expect((await f.rows()).single.completedAt, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  challengeTestWidgets(
    'challenge start failure keeps real data and permits explicit retry',
    (tester) async {
      final f = await pumpChallenges(
        tester,
        configure: (repository) => repository.startFailures = 1,
      );
      await f.tapText('Start challenge');
      await f.tapText('7 days of protein support');
      expect(await f.rows(), isEmpty);
      expect(
        find.text(f.t('Your saved data was not changed. Try again.')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await f.tapText('Start challenge');
      await f.tapText('7 days of protein support');
      final row = (await f.rows()).single;
      expect(row.type, 'protein');
      expect(row.audience, 'private');
      expect(row.targetDays, 7);
      expect(row.status, 'active');
      expect(f.repository.startCalls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  challengeTestWidgets(
    'challenge delete failure retains row until successful tombstone retry',
    (tester) async {
      final f = await pumpChallenges(
        tester,
        seedChallenge: true,
        configure: (repository) => repository.deleteFailures = 1,
      );
      await f.tapDelete();
      expect((await f.rows()).single.deletedAt, isNull);
      expect(
        find.text(f.t('Your saved data was not changed. Try again.')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await f.tapDelete();
      final row = (await f.rows()).single;
      expect(row.deletedAt, isNotNull);
      expect(row.syncStatus, 'pendingDelete');
      expect(row.revision, 2);
      expect(f.repository.deleteCalls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  challengeTestWidgets(
    'challenge start is single flight while its real write is pending',
    (tester) async {
      final gate = Completer<void>();
      final f = await pumpChallenges(
        tester,
        configure: (repository) => repository.startBarrier = gate,
      );
      await f.tapText('Start challenge');
      await f.tapText('7 days of protein support');
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNull);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(f.repository.startCalls, 1);
      expect(await f.rows(), isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
      expect(await f.rows(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  challengeTestWidgets(
    'challenge delete is single flight while its real write is pending',
    (tester) async {
      final gate = Completer<void>();
      final f = await pumpChallenges(
        tester,
        seedChallenge: true,
        configure: (repository) => repository.deleteBarrier = gate,
      );
      await f.tapDelete();
      expect(tester.widget<IconButton>(f.deleteButton).onPressed, isNull);
      await tester.tap(f.deleteButton);
      await tester.pump();
      expect(f.repository.deleteCalls, 1);
      expect((await f.rows()).single.deletedAt, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect((await f.rows()).single.deletedAt, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final operation in ['start', 'delete']) {
    challengeTestWidgets(
      'accepted challenge $operation finishes after leaving without stale UI access',
      (tester) async {
        final gate = Completer<void>();
        final f = await pumpChallenges(
          tester,
          seedChallenge: operation == 'delete',
          configure: (repository) {
            if (operation == 'start') {
              repository.startBarrier = gate;
            }
            if (operation == 'delete') {
              repository.deleteBarrier = gate;
            }
          },
        );
        if (operation == 'start') {
          await f.tapText('Start challenge');
          await f.tapText('7 days of protein support');
        } else {
          await f.tapDelete();
        }
        f.router.go('/dashboard');
        await tester.pumpAndSettle();
        gate.complete();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('challenge-return-dashboard')),
          findsOneWidget,
        );
        final row = (await f.rows()).single;
        if (operation == 'start') {
          expect(row.status, 'active');
        }
        if (operation == 'delete') {
          expect(row.deletedAt, isNotNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
