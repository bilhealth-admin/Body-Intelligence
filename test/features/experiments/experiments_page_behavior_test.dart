import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/experiment_repository.dart';
import 'package:body_intelligence_log/features/experiments/experiments_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'experiments_fixture.dart';

void main() {
  test(
    'concurrent experiment starts preserve a single active SQLite row',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = ExperimentRepository(database);
      Future<bool> start() async {
        try {
          await seedActiveExperiment(repository);
          return true;
        } on StateError {
          return false;
        }
      }

      final accepted = await Future.wait([start(), start()]);
      expect(accepted.where((value) => value), hasLength(1));
      final rows = await database.select(database.personalExperiments).get();
      expect(rows.where((row) => row.status == 'active'), hasLength(1));
    },
  );

  experimentTestWidgets(
    'pending experiment read and failed read recover through Retry',
    (tester) async {
      final read = Completer<void>();
      final f = await pumpExperiments(
        tester,
        settle: false,
        configure: (repository) {
          repository.watchBarrier = read;
          repository.watchFailures = 1;
        },
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ExperimentsPage)),
      );
      expect(find.byType(BilFeatureWelcomeStatus), findsOneWidget);
      expect(container.read(experimentsProvider).isLoading, isTrue);
      expect(f.repository.watchCalls, 1);
      expect(await f.rows(), isEmpty);
      read.complete();
      await tester.pumpAndSettle();
      expect(container.read(experimentsProvider).hasError, isTrue);
      expect(container.read(experimentsProvider).isLoading, isFalse);
      expect(
        find.text(f.t('Your saved data was not changed. Try again.')),
        findsOneWidget,
      );
      // Passing the framework's first automatic-retry delay must not conceal
      // this failure or resubscribe before the user explicitly chooses Retry.
      await tester.pump(const Duration(milliseconds: 250));
      expect(f.repository.watchCalls, 1);
      expect(container.read(experimentsProvider).hasError, isTrue);
      await f.tap(tester, 'Retry');
      expect(f.repository.watchCalls, 2);
      expect(container.read(experimentsProvider).hasValue, isTrue);
      expect(container.read(experimentsProvider).isLoading, isFalse);
      expect(
        find.text(f.t('Choose one thing to learn this week')),
        findsOneWidget,
      );
      expect(await f.rows(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'ar']) {
    experimentTestWidgets(
      'preset create and one active experiment use real SQLite $language',
      (tester) async {
        final f = await pumpExperiments(tester, language: language);
        await f.tap(tester, 'Protein-first breakfast');
        await f.tap(tester, '14 days');
        await f.tap(tester, 'Start my experiment');
        final rows = await f.rows();
        expect(rows, hasLength(1));
        final row = rows.single;
        expect(row.status, 'active');
        expect(
          row.hypothesis,
          f.t(
            'A protein-first breakfast may improve my satiety and energy through the morning.',
          ),
        );
        expect(row.endsAt.difference(row.startedAt).inDays + 1, 14);
        expect(
          row.changedVariable,
          f.t('Start breakfast with a consistent protein source'),
        );
        expect(find.text(f.t('Design a custom experiment')), findsNothing);
        await expectLater(
          f.real(() => seedActiveExperiment(f.repository)),
          throwsStateError,
        );
        expect(await f.rows(), hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    experimentTestWidgets(
      'custom validation retains editable values before any write $language',
      (tester) async {
        final f = await pumpExperiments(tester, language: language);
        await f.tap(tester, 'Design a custom experiment');
        await tester.enterText(
          f.field('What do you want to learn?'),
          'Test earlier dinner',
        );
        await tester.enterText(
          f.field('What should BIL watch?'),
          'Recorded sleep',
        );
        tester.testTextInput.hide();
        await f.tap(tester, 'Start my experiment');
        expect(f.field('What do you want to learn?'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(f.field('What do you want to learn?'))
              .controller!
              .text,
          'Test earlier dinner',
        );
        expect(find.text(f.t('Check the experiment details.')), findsOneWidget);
        expect(await f.rows(), isEmpty);
        await tester.enterText(
          f.field('The one change you will make'),
          'Finish dinner earlier',
        );
        tester.testTextInput.hide();
        await f.tap(tester, '3 days');
        await f.tap(tester, 'Start my experiment');
        final row = (await f.rows()).single;
        expect(row.hypothesis, 'Test earlier dinner');
        expect(row.changedVariable, 'Finish dinner earlier');
        expect(row.requiredData, 'Recorded sleep');
        expect(row.endsAt.difference(row.startedAt).inDays + 1, 3);
        expect(tester.takeException(), isNull);
      },
    );

    experimentTestWidgets(
      'custom create failure preserves draft and permits one retry $language',
      (tester) async {
        final f = await pumpExperiments(
          tester,
          language: language,
          configure: (repository) => repository.createFailures = 1,
        );
        await f.tap(tester, 'Design a custom experiment');
        await tester.enterText(
          f.field('What do you want to learn?'),
          'My retained question',
        );
        await tester.enterText(
          f.field('The one change you will make'),
          'One retained change',
        );
        tester.testTextInput.hide();
        await f.tap(tester, 'Start my experiment');
        expect(await f.rows(), isEmpty);
        expect(f.field('What do you want to learn?'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(f.field('What do you want to learn?'))
              .controller!
              .text,
          'My retained question',
        );
        expect(
          find.text(f.t('The experiment could not be started.')),
          findsOneWidget,
        );
        await f.tap(tester, 'Start my experiment');
        expect(f.repository.createCalls, 2);
        expect((await f.rows()).single.hypothesis, 'My retained question');
        expect(tester.takeException(), isNull);
      },
    );

    experimentTestWidgets(
      'complete persists user adherence and observations in SQLite $language',
      (tester) async {
        final f = await pumpExperiments(
          tester,
          language: language,
          seedActive: true,
        );
        await f.tap(tester, 'Record what happened');
        expect(tester.takeException(), isNull);
        final slider = find.byType(Slider);
        final rect = tester.getRect(slider);
        await tester.tapAt(
          Offset(
            language == 'ar' ? rect.left + 24 : rect.right - 24,
            rect.center.dy,
          ),
        );
        await tester.pumpAndSettle();
        final chosenAdherence = tester.widget<Slider>(slider).value;
        expect(chosenAdherence, greaterThan(80));
        expect(chosenAdherence, lessThanOrEqualTo(100));
        await tester.enterText(
          f.field('Your observation'),
          'Morning energy felt steadier.',
        );
        await tester.enterText(
          f.field('Anything that affected the result?'),
          'Travel changed two days.',
        );
        tester.testTextInput.hide();
        await f.tap(tester, 'A weak signal');
        await f.tap(tester, 'A repeatable signal');
        await f.tap(tester, 'Save what BIL learned');
        final row = (await f.rows()).single;
        expect(row.status, 'completed');
        expect(row.adherence, chosenAdherence);
        expect(row.result, 'Morning energy felt steadier.');
        expect(row.limitations, 'Travel changed two days.');
        expect(row.confidence, 'moderate');
        expect(row.revision, 2);
        expect(row.syncStatus, 'pending');
        expect(await f.real(f.repository.active), isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  experimentTestWidgets(
    'completion failure retains observation and retries without data loss',
    (tester) async {
      final f = await pumpExperiments(
        tester,
        seedActive: true,
        configure: (repository) => repository.completeFailures = 1,
      );
      await f.tap(tester, 'Record what happened');
      await tester.enterText(
        f.field('Your observation'),
        'Retained observation',
      );
      tester.testTextInput.hide();
      await f.tap(tester, 'Save what BIL learned');
      expect((await f.rows()).single.status, 'active');
      expect(
        tester.widget<TextField>(f.field('Your observation')).controller!.text,
        'Retained observation',
      );
      expect(
        find.text(f.t('Your saved data was not changed. Try again.')),
        findsOneWidget,
      );
      await f.tap(tester, 'Save what BIL learned');
      expect(f.repository.completeCalls, 2);
      expect((await f.rows()).single.result, 'Retained observation');
      expect((await f.rows()).single.status, 'completed');
      expect(tester.takeException(), isNull);
    },
  );

  experimentTestWidgets(
    'cancelling custom and completion sheets never writes or uses disposed controllers',
    (tester) async {
      final f = await pumpExperiments(tester);
      await f.tap(tester, 'Design a custom experiment');
      await tester.enterText(
        f.field('What do you want to learn?'),
        'Unsubmitted question',
      );
      f.router.pop();
      await tester.pumpAndSettle();
      expect(await f.rows(), isEmpty);
      await f.real(() => seedActiveExperiment(f.repository));
      await tester.pumpAndSettle();
      await f.tap(tester, 'Record what happened');
      await tester.enterText(
        f.field('Your observation'),
        'Unsubmitted observation',
      );
      f.router.pop();
      await tester.pumpAndSettle();
      expect((await f.rows()).single.status, 'active');
      expect((await f.rows()).single.result, isNull);
      expect(f.repository.completeCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  experimentTestWidgets(
    'delete Keep and failed retry preserve row until a real tombstone write',
    (tester) async {
      final f = await pumpExperiments(
        tester,
        seedActive: true,
        configure: (repository) => repository.deleteFailures = 1,
      );
      await tester.tap(find.byTooltip(f.t('Delete experiment')));
      await tester.pumpAndSettle();
      await f.tap(tester, 'Keep');
      expect((await f.rows()).single.deletedAt, isNull);
      expect(f.repository.deleteCalls, 0);
      await tester.tap(find.byTooltip(f.t('Delete experiment')));
      await tester.pumpAndSettle();
      await f.tap(tester, 'Delete');
      expect((await f.rows()).single.deletedAt, isNull);
      expect(
        find.text(f.t('Your saved data was not changed. Try again.')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip(f.t('Delete experiment')));
      await tester.pumpAndSettle();
      await f.tap(tester, 'Delete');
      final row = (await f.rows()).single;
      expect(row.deletedAt, isNotNull);
      expect(row.syncStatus, 'pendingDelete');
      expect(row.revision, 2);
      expect(f.repository.deleteCalls, 2);
      expect(await f.real(() => f.repository.watchAll().first), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final operation in ['create', 'complete']) {
    experimentTestWidgets(
      '$operation submit is single flight while SQLite write is pending',
      (tester) async {
        final pending = Completer<void>();
        final f = await pumpExperiments(
          tester,
          seedActive: operation == 'complete',
          configure: (repository) {
            if (operation == 'create') repository.createBarrier = pending;
            if (operation == 'complete') repository.completeBarrier = pending;
          },
        );
        if (operation == 'create') {
          await f.tap(tester, 'Design a custom experiment');
          await tester.enterText(
            f.field('What do you want to learn?'),
            'One pending question',
          );
          await tester.enterText(
            f.field('The one change you will make'),
            'One pending change',
          );
          tester.testTextInput.hide();
        } else {
          await f.tap(tester, 'Record what happened');
        }
        final label = operation == 'create'
            ? 'Start my experiment'
            : 'Save what BIL learned';
        await f.tap(tester, label);
        final button = find
            .ancestor(
              of: find.text(f.t(label)).last,
              matching: find.byType(FilledButton),
            )
            .first;
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        await tester.tap(find.text(f.t(label)).last);
        await tester.pump();
        expect(
          operation == 'create'
              ? f.repository.createCalls
              : f.repository.completeCalls,
          1,
        );
        pending.complete();
        await tester.pumpAndSettle();
        final rows = await f.rows();
        expect(rows, hasLength(1));
        expect(
          rows.single.status,
          operation == 'create' ? 'active' : 'completed',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final operation in ['create', 'complete', 'delete']) {
    experimentTestWidgets(
      '$operation accepted write can finish after leaving without a stale UI callback',
      (tester) async {
        final pending = Completer<void>();
        final f = await pumpExperiments(
          tester,
          seedActive: operation != 'create',
          configure: (repository) {
            switch (operation) {
              case 'create':
                repository.createBarrier = pending;
              case 'complete':
                repository.completeBarrier = pending;
              case 'delete':
                repository.deleteBarrier = pending;
            }
          },
        );
        if (operation == 'create') {
          await f.tap(tester, 'Design a custom experiment');
          await tester.enterText(
            f.field('What do you want to learn?'),
            'Accepted before leave',
          );
          await tester.enterText(
            f.field('The one change you will make'),
            'One accepted change',
          );
          tester.testTextInput.hide();
          await f.tap(tester, 'Start my experiment');
        } else if (operation == 'complete') {
          await f.tap(tester, 'Record what happened');
          await f.tap(tester, 'Save what BIL learned');
        } else {
          await tester.tap(find.byTooltip(f.t('Delete experiment')));
          await tester.pumpAndSettle();
          await f.tap(tester, 'Delete');
        }
        f.router.go('/dashboard');
        await tester.pumpAndSettle();
        pending.complete();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('experiments-return-dashboard')),
          findsOneWidget,
        );
        final row = (await f.rows()).single;
        if (operation == 'create') expect(row.status, 'active');
        if (operation == 'complete') expect(row.status, 'completed');
        if (operation == 'delete') expect(row.deletedAt, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final pushed in [false, true]) {
    experimentTestWidgets('Experiments back returns safely pushed=$pushed', (
      tester,
    ) async {
      final f = await pumpExperiments(tester, pushed: pushed);
      expect(find.byType(ExperimentsPage), findsOneWidget);
      await tester.tap(find.byKey(const Key('secondary-page-back')));
      await tester.pumpAndSettle();
      expect(f.router.state.uri.path, '/dashboard');
      expect(
        find.byKey(const Key('experiments-return-dashboard')),
        findsOneWidget,
      );
      expect(await f.rows(), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'every existing experiment caption resolves in all 25 canonical locales',
    () {
      final source = [
        'lib/features/experiments/experiments_page.dart',
        'lib/features/experiments/experiments_components.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      final keys = RegExp(
        r"\bt\(\s*'([^']+)'",
      ).allMatches(source).map((match) => match.group(1)!).toSet();
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        for (final key in keys) {
          expect(RuntimeCopy.resolve(key, tag), isNotNull, reason: '$tag:$key');
        }
      }
    },
  );
}
