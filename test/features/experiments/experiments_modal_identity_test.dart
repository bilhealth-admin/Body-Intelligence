import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'experiments_fixture.dart';

Future<void> _pumpUntilCommitted(
  WidgetTester tester,
  ExperimentsFixture fixture, {
  required String status,
}) async {
  // Complete native SQLite work without advancing the fake animation clock.
  // This keeps the user's reverse-dismiss transition genuinely in progress.
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(Duration.zero);
    final rows = await fixture.rows();
    if (rows.length == 1 && rows.single.status == status) {
      await tester.pump(Duration.zero);
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Accepted SQLite write did not finish within bounded zero-time frames.');
}

void main() {
  experimentTestWidgets(
    'pending completion during dismissed sheet transition retains the underlying page',
    (tester) async {
      final gate = Completer<void>();
      final f = await pumpExperiments(
        tester,
        seedActive: true,
        pushed: true,
        configure: (repository) => repository.completeBarrier = gate,
      );
      await f.tap(tester, 'Record what happened');
      await tester.enterText(
        f.field('Your observation'),
        'Accepted before dismiss',
      );
      tester.testTextInput.hide();
      final sheetContext = tester.element(find.byType(Slider));
      final ownRoute = ModalRoute.of(sheetContext)!;
      final navigator = ownRoute.navigator!;
      await f.tap(tester, 'Save what BIL learned');
      expect(f.repository.completeCalls, 1);

      // A real user dismissal starts the sheet's reverse animation. The
      // element remains mounted, while its route is no longer active/current.
      navigator.pop();
      await tester.pump(const Duration(milliseconds: 1));
      expect(sheetContext.mounted, isTrue);
      expect(ownRoute.isActive, isFalse);
      expect(ownRoute.isCurrent, isFalse);
      gate.complete();
      await _pumpUntilCommitted(tester, f, status: 'completed');

      expect(
        sheetContext.mounted,
        isTrue,
        reason:
            'The accepted write completed inside the reverse transition window.',
      );
      expect(f.router.state.uri.path, '/experiments');
      expect(f.router.canPop(), isTrue);
      expect((await f.rows()).single.result, 'Accepted before dismiss');
      await tester.pumpAndSettle();
      expect(f.router.state.uri.path, '/experiments');
      expect(find.byType(Slider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  experimentTestWidgets(
    'pending create removes only its covered sheet and preserves unrelated top route',
    (tester) async {
      final gate = Completer<void>();
      final f = await pumpExperiments(
        tester,
        pushed: true,
        configure: (repository) => repository.createBarrier = gate,
      );
      await f.tap(tester, 'Design a custom experiment');
      await tester.enterText(
        f.field('What do you want to learn?'),
        'One accepted question',
      );
      await tester.enterText(
        f.field('The one change you will make'),
        'One accepted change',
      );
      tester.testTextInput.hide();
      final sheetContext = tester.element(
        f.field('What do you want to learn?'),
      );
      final ownRoute = ModalRoute.of(sheetContext)!;
      final navigator = ownRoute.navigator!;
      var ownRouteCompleted = false;
      unawaited(
        ownRoute.completed.then<void>((_) {
          ownRouteCompleted = true;
        }),
      );
      await f.tap(tester, 'Start my experiment');
      expect(f.repository.createCalls, 1);
      final unrelated = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'unrelated-after-pending-save'),
        builder: (_) => const Scaffold(
          key: Key('unrelated-after-pending-save'),
          body: Text('Unrelated page stays open'),
        ),
      );
      unawaited(navigator.push<void>(unrelated));
      await tester.pumpAndSettle();
      expect(sheetContext.mounted, isTrue);
      expect(ownRoute.isActive, isTrue);
      expect(ownRoute.isCurrent, isFalse);
      expect(unrelated.isCurrent, isTrue);
      gate.complete();
      await _pumpUntilCommitted(tester, f, status: 'active');
      await tester.pump(Duration.zero);

      expect(unrelated.isCurrent, isTrue);
      expect(
        find.byKey(const Key('unrelated-after-pending-save')).hitTestable(),
        findsOneWidget,
      );
      expect(ownRoute.isActive, isFalse);
      expect(
        ownRouteCompleted,
        isTrue,
        reason:
            'The saved covered editor is removed and its disposal future completes.',
      );
      expect((await f.rows()).single.hypothesis, 'One accepted question');
      expect(f.repository.createCalls, 1);

      // Back returns to the ordinary page, without reviving a saved editor
      // or offering a second submission of its already accepted data.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(f.router.state.uri.path, '/experiments');
      expect(find.byType(TextField), findsNothing);
      expect(find.text(f.t('Start my experiment')), findsNothing);
      expect(f.repository.createCalls, 1);
      expect(await f.rows(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
