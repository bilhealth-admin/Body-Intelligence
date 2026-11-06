import 'dart:async';

import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_memory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'life_memory_fixture.dart';

Future<void> openLifeDraft(LifeMemoryFixture f) async {
  await f.tapText('Add context');
  await f.tapText('Travel');
}

Finder rating(LifeMemoryFixture f, int value) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == '$value ${f.t('of 5')}',
);

void main() {
  for (final language in ['en', 'ar']) {
    lifeMemoryTestWidgets(
      'life context failed save retains draft and consent for retry $language',
      (tester) async {
        final f = await pumpLifeMemory(tester, language: language);
        f.life.addFailures = 1;
        await openLifeDraft(f);
        await tester.enterText(
          find.byType(TextField),
          'Synthetic retained travel note',
        );
        await f.tap(find.byType(SwitchListTile));
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse,
        );
        tester.testTextInput.hide();
        await f.tapText('Save');
        await f.waitFor(() => f.life.addFinished == 1);
        expect(
          find.byType(TextField),
          findsOneWidget,
          reason: 'failed persistence must not dismiss the editable dialog',
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Synthetic retained travel note',
        );
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse,
        );
        expect(find.text(f.t('Could not save changes.')), findsOneWidget);
        expect(await f.lifeRows(), isEmpty);
        await f.tapText('Save');
        await f.waitFor(() => find.byType(TextField).evaluate().isEmpty);
        final row = (await f.lifeRows()).single;
        expect(row.type, 'travel');
        expect(row.details, 'Synthetic retained travel note');
        expect(row.useInInsights, isFalse);
        expect(row.deletedAt, isNull);
        expect(f.life.addCalls, 2);
        expect(tester.takeException(), isNull);
      },
    );

    lifeMemoryTestWidgets(
      'life context pending save is single flight and cannot dismiss draft $language',
      (tester) async {
        final f = await pumpLifeMemory(tester, language: language);
        final gate = Completer<void>();
        f.life.addBarrier = gate;
        await openLifeDraft(f);
        await tester.enterText(
          find.byType(TextField),
          'Synthetic one-write note',
        );
        tester.testTextInput.hide();
        final save = find.text(f.t('Save'));
        await tester.tap(save);
        await tester.tap(save);
        await tester.pump();
        expect(f.life.addCalls, 1);
        expect(find.byType(TextField), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
          isNull,
        );
        expect(await f.lifeRows(), isEmpty);
        await Navigator.of(tester.element(find.byType(TextField))).maybePop();
        await tester.pumpAndSettle();
        expect(
          find.byType(TextField),
          findsOneWidget,
          reason: 'pending save keeps the draft and cannot be popped',
        );
        gate.complete();
        await f.waitFor(() => f.life.addFinished == 1);
        await tester.pumpAndSettle();
        expect(await f.lifeRows(), hasLength(1));
        expect(f.life.addCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );

    lifeMemoryTestWidgets(
      'decision rating failed write stays unrated and retries once $language',
      (tester) async {
        final f = await pumpLifeMemory(
          tester,
          memory: true,
          language: language,
          seed: (f) async {
            await f.seedMemory();
          },
        );
        f.memory.evaluateFailures = 1;
        final gate = Completer<void>();
        f.memory.evaluateBarrier = gate;
        await f.tapText('Synthetic recommendation');
        await tester.ensureVisible(rating(f, 3));
        await tester.tap(rating(f, 3));
        await tester.tap(rating(f, 3));
        await tester.pump();
        expect(f.memory.evaluateCalls, 1);
        expect(tester.widget<IconButton>(rating(f, 3)).onPressed, isNull);
        expect((await f.memoryRows()).single.helpfulness, isNull);
        gate.complete();
        await f.waitFor(
          () => find.text(f.t('Could not save changes.')).evaluate().isNotEmpty,
        );
        expect((await f.memoryRows()).single.helpfulness, isNull);
        await f.tap(rating(f, 3));
        await f.waitFor(() => f.memory.evaluateFinished == 2);
        final row = (await f.memoryRows()).single;
        expect(row.helpfulness, 3);
        expect(row.revision, 2);
        expect(row.deletedAt, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    lifeMemoryTestWidgets(
      'decision delete failure preserves visible record and permits retry $language',
      (tester) async {
        final f = await pumpLifeMemory(
          tester,
          memory: true,
          language: language,
          seed: (f) async {
            await f.seedMemory();
          },
        );
        f.memory.deleteFailures = 1;
        await f.tapText('Synthetic recommendation');
        await f.tapText('Delete memory');
        await f.waitFor(
          () => find.text(f.t('Could not save changes.')).evaluate().isNotEmpty,
        );
        expect((await f.memoryRows()).single.deletedAt, isNull);
        expect(find.text('Synthetic recommendation'), findsOneWidget);
        await f.tapText('Delete memory');
        await f.waitFor(
          () => find.text('Synthetic recommendation').evaluate().isEmpty,
        );
        expect((await f.memoryRows()).single.deletedAt, isNotNull);
        expect(f.memory.deleteCalls, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  lifeMemoryTestWidgets(
    'life context cancel discards no stored record and closes controller safely',
    (tester) async {
      final f = await pumpLifeMemory(tester);
      await openLifeDraft(f);
      await tester.enterText(
        find.byType(TextField),
        'Synthetic cancelled note',
      );
      tester.testTextInput.hide();
      await f.tapText('Cancel');
      expect(await f.lifeRows(), isEmpty);
      expect(f.life.addCalls, 0);
      await openLifeDraft(f);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await f.tapText('Cancel');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final operation in ['consent', 'delete']) {
    lifeMemoryTestWidgets(
      'life context $operation failure preserves row and unlocks retry',
      (tester) async {
        final f = await pumpLifeMemory(
          tester,
          seed: (f) async {
            await f.seedLife();
          },
        );
        if (operation == 'consent') f.life.consentFailures = 1;
        if (operation == 'delete') f.life.deleteFailures = 1;
        Future<void> invoke() async {
          await f.tap(find.byType(PopupMenuButton<String>));
          await f.tapText(
            operation == 'consent' ? 'Exclude from insights' : 'Delete',
          );
        }

        await invoke();
        await f.waitFor(
          () => find.text(f.t('Could not save changes.')).evaluate().isNotEmpty,
        );
        final unchanged = (await f.lifeRows()).single;
        expect(unchanged.useInInsights, isTrue);
        expect(unchanged.deletedAt, isNull);
        expect(unchanged.revision, 1);
        await invoke();
        await f.waitFor(
          () => operation == 'consent'
              ? find
                    .descendant(
                      of: find.byType(ListTile),
                      matching: find.text(
                        'Synthetic context\n${f.t('Excluded from insights')}',
                      ),
                    )
                    .evaluate()
                    .isNotEmpty
              : find.text('Synthetic context').evaluate().isEmpty,
        );
        final changed = (await f.lifeRows()).single;
        expect(changed.revision, 2);
        expect(changed.useInInsights, operation == 'delete');
        expect(changed.deletedAt == null, operation == 'consent');
        expect(tester.takeException(), isNull);
      },
    );
  }

  lifeMemoryTestWidgets(
    'decision response setting failure keeps current consent and retries',
    (tester) async {
      final f = await pumpLifeMemory(tester, memory: true);
      const key = 'decisionMemoryEnabled';
      f.preferences.failures[key] = 1;
      final gate = Completer<void>();
      f.preferences.barriers[key] = gate;
      await f.tap(find.byType(SwitchListTile));
      expect(f.preferences.calls[key], 1);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      gate.complete();
      await f.waitFor(
        () => find.text(f.t('Could not save changes.')).evaluate().isNotEmpty,
      );
      expect(await f.real(() => f.preferences.get(key)), isNull);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await f.tap(find.byType(SwitchListTile));
      await f.waitFor(
        () => !tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      );
      expect(await f.real(() => f.preferences.get(key)), 'false');
      expect(f.preferences.calls[key], 2);
      expect(tester.takeException(), isNull);
    },
  );

  lifeMemoryTestWidgets(
    'unhelpful forget failure retains confirmation and only retries selected scope',
    (tester) async {
      final f = await pumpLifeMemory(
        tester,
        memory: true,
        seed: (f) async {
          await f.seedMemory(helpfulness: 2);
          await f.seedMemory(
            type: BestActionType.protein,
            title: 'Synthetic helpful recommendation',
            helpfulness: 4,
          );
        },
      );
      f.memory.forgetFailures = 1;
      await f.tapText('Forget unhelpful memories');
      await f.tapText('Forget');
      await f.waitFor(
        () => find.text(f.t('Could not save changes.')).evaluate().isNotEmpty,
      );
      expect(find.text(f.t('Forget memories?')), findsOneWidget);
      expect(
        (await f.memoryRows()).every((row) => row.deletedAt == null),
        isTrue,
      );
      await f.tapText('Forget');
      await f.waitFor(
        () => find.text(f.t('Forget memories?')).evaluate().isEmpty,
      );
      final rows = await f.memoryRows();
      expect(
        rows.singleWhere((row) => row.helpfulness == 2).deletedAt,
        isNotNull,
      );
      expect(rows.singleWhere((row) => row.helpfulness == 4).deletedAt, isNull);
      expect(f.memory.forgetCalls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  lifeMemoryTestWidgets(
    'explicit forget storage failure retains reviewed memory and retries its exact selection',
    (tester) async {
      final f = await pumpLifeMemory(
        tester,
        memory: true,
        seed: (f) async {
          await f.seedExplicit('Synthetic confirmed fact A');
          await f.seedExplicit('Synthetic confirmed fact B');
        },
      );
      f.preferences.failures[CoachMemoryRepository.storageKey] = 1;
      final tile = find.ancestor(
        of: find.text('Synthetic confirmed fact A'),
        matching: find.byType(ListTile),
      );
      await f.tap(find.descendant(of: tile, matching: find.byType(IconButton)));
      await f.tapText('Forget');
      await f.waitFor(
        () => find.text(f.t('Could not save changes.')).evaluate().isNotEmpty,
      );
      expect(find.text(f.t('Forget this memory?')), findsOneWidget);
      expect(
        await f.real(
          () => CoachMemoryRepository(preferences: f.preferences).readLocal(),
        ),
        hasLength(2),
      );
      await f.tapText('Forget');
      await f.waitFor(
        () => find.text('Synthetic confirmed fact A').evaluate().isEmpty,
      );
      final retained = await f.real(
        () => CoachMemoryRepository(preferences: f.preferences).readLocal(),
      );
      expect(retained, hasLength(1));
      expect(retained.single['text'], 'Synthetic confirmed fact B');
      expect(tester.takeException(), isNull);
    },
  );

  lifeMemoryTestWidgets(
    'decision memory forget dismisses only its captured covered dialog',
    (tester) async {
      final f = await pumpLifeMemory(
        tester,
        memory: true,
        seed: (f) async {
          await f.seedMemory(helpfulness: 2);
          await f.seedMemory(
            type: BestActionType.protein,
            title: 'Synthetic retained helpful recommendation',
            helpfulness: 4,
          );
        },
      );
      final gate = Completer<void>();
      f.memory.forgetBarrier = gate;
      await f.tapText('Forget unhelpful memories');
      final dialogContext = tester.element(
        find.byKey(const Key('decision-memory-confirm')),
      );
      final dialogRoute = ModalRoute.of(dialogContext)!;
      final navigator = dialogRoute.navigator!;
      await tester.tap(find.byKey(const Key('decision-memory-confirm')));
      await tester.pump(Duration.zero);
      expect(f.memory.forgetCalls, 1);
      expect(dialogRoute.isActive, isTrue);
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isFalse,
      );
      final otherRoute = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          key: Key('decision-memory-async-other-route'),
          body: Text('Synthetic unrelated memory route'),
        ),
      );
      unawaited(navigator.push<void>(otherRoute));
      await tester.pump(Duration.zero);
      expect(
        otherRoute.isCurrent,
        isTrue,
        reason:
            'canPop guards dismissal; it does not prevent another route being pushed',
      );
      expect(dialogRoute.isActive, isTrue);
      expect(dialogRoute.isCurrent, isFalse);
      expect(dialogContext.mounted, isTrue);
      gate.complete();
      final watch = Stopwatch()..start();
      while (dialogRoute.isActive &&
          otherRoute.isActive &&
          watch.elapsed < const Duration(seconds: 5)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(Duration.zero);
      }
      expect(
        otherRoute.isActive,
        isTrue,
        reason:
            'the completed memory write must never pop the unrelated current route',
      );
      expect(otherRoute.isCurrent, isTrue);
      expect(dialogRoute.isActive, isFalse);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('decision-memory-async-other-route')),
        findsOneWidget,
      );
      final rows = await f.memoryRows();
      expect(
        rows.singleWhere((row) => row.helpfulness == 2).deletedAt,
        isNotNull,
      );
      expect(rows.singleWhere((row) => row.helpfulness == 4).deletedAt, isNull);
      expect(f.memory.forgetCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final alreadyDismissed in [false, true]) {
    lifeMemoryTestWidgets(
      'life context save dismisses only its captured route (already dismissed=$alreadyDismissed)',
      (tester) async {
        final f = await pumpLifeMemory(tester);
        final gate = Completer<void>();
        f.life.addBarrier = gate;
        await openLifeDraft(f);
        await tester.enterText(
          find.byType(TextField),
          'Synthetic modal identity note',
        );
        tester.testTextInput.hide();
        final draftContext = tester.element(find.byType(TextField));
        final draftRoute = ModalRoute.of(draftContext)!;
        final navigator = draftRoute.navigator!;
        await tester.tap(find.text(f.t('Save')));
        await tester.pump(Duration.zero);
        expect(f.life.addCalls, 1);
        if (alreadyDismissed) {
          // External navigation can dismiss a modal despite its pending-write
          // back guard. Keep virtual time fixed in its reverse transition.
          navigator.pop();
        }
        final otherRoute = MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            key: Key('life-context-async-other-route'),
            body: Text('Synthetic unrelated route'),
          ),
        );
        unawaited(navigator.push<void>(otherRoute));
        await tester.pump(Duration.zero);
        expect(otherRoute.isActive, isTrue);
        expect(otherRoute.isCurrent, isTrue);
        expect(
          draftContext.mounted,
          isTrue,
          reason:
              'the async completion must occur while the old dialog is still mounted',
        );
        expect(draftRoute.isActive, !alreadyDismissed);
        gate.complete();
        final watch = Stopwatch()..start();
        while (f.life.addFinished == 0 &&
            watch.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(Duration.zero);
        }
        expect(f.life.addFinished, 1);
        await tester.pump(Duration.zero);
        expect(
          otherRoute.isActive,
          isTrue,
          reason:
              'finishing an old dialog write must never pop the unrelated current route',
        );
        expect(otherRoute.isCurrent, isTrue);
        expect(draftRoute.isActive, isFalse);
        if (alreadyDismissed) {
          expect(
            draftContext.mounted,
            isTrue,
            reason: 'an already reversing modal must not be dismissed twice',
          );
        }
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('life-context-async-other-route')),
          findsOneWidget,
        );
        expect(
          (await f.lifeRows()).single.details,
          'Synthetic modal identity note',
        );
        expect(f.life.addCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final failure in [false, true]) {
    lifeMemoryTestWidgets(
      'life context unmount during save is safe (failure=$failure)',
      (tester) async {
        final f = await pumpLifeMemory(tester);
        final gate = Completer<void>();
        f.life.addBarrier = gate;
        f.life.addFailures = failure ? 1 : 0;
        await openLifeDraft(f);
        await tester.enterText(
          find.byType(TextField),
          'Synthetic unmount note',
        );
        tester.testTextInput.hide();
        await f.tapText('Save');
        expect(f.life.addCalls, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        gate.complete();
        await f.waitFor(() => f.life.addFinished == 1);
        await tester.pumpAndSettle();
        expect(await f.lifeRows(), hasLength(failure ? 0 : 1));
        expect(f.life.addCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );

    lifeMemoryTestWidgets(
      'decision memory unmount during rating is safe (failure=$failure)',
      (tester) async {
        final f = await pumpLifeMemory(
          tester,
          memory: true,
          seed: (f) async {
            await f.seedMemory();
          },
        );
        final gate = Completer<void>();
        f.memory.evaluateBarrier = gate;
        f.memory.evaluateFailures = failure ? 1 : 0;
        await f.tapText('Synthetic recommendation');
        await f.tap(rating(f, 4));
        expect(f.memory.evaluateCalls, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        gate.complete();
        await f.waitFor(() => f.memory.evaluateFinished == 1);
        await tester.pumpAndSettle();
        expect((await f.memoryRows()).single.helpfulness, failure ? isNull : 4);
        expect(f.memory.evaluateCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
