part of '../coach_page_lifecycle_regression_test.dart';

void registerCoachScrollCases() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final arabic in [false, true]) {
      testWidgets(
        'slow touch scroll through a long new reply $platform Arabic=$arabic',
        (tester) async {
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          final gateway = _HeldGateway();
          await _mount(
            tester,
            database: database,
            gateway: gateway,
            gate: true,
            platform: platform,
            arabic: arabic,
          );
          await _send(tester, gateway);
          gateway.finish(
            text: List.generate(
              65,
              (i) => arabic
                  ? 'تفاصيل الإجابة $i: يمكن قراءة هذه الرسالة والعودة إليها.'
                  : 'Reply detail $i: read this saved answer and return to it.',
            ).join('\n'),
          );
          await tester.pumpAndSettle();
          final history = find.byType(ChatHistoryViewport);
          final scroll = tester.widget<ChatHistoryViewport>(history).controller;
          final latest = scroll.position.minScrollExtent;
          expect(scroll.offset, closeTo(latest, .5));
          final down = await tester.startGesture(tester.getCenter(history));
          for (var i = 0; i < 24; i++) {
            await down.moveBy(const Offset(0, 6));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await down.up();
          await tester.pumpAndSettle();
          final older = scroll.offset;
          expect(
            older - latest,
            greaterThan(72),
            reason: 'A continuous slow drag must escape the newest reply.',
          );
          final up = await tester.startGesture(tester.getCenter(history));
          for (var i = 0; i < 16; i++) {
            await up.moveBy(const Offset(0, -6));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await up.up();
          await tester.pumpAndSettle();
          expect(
            scroll.offset,
            lessThan(older - 40),
            reason: 'A slow upward drag must also move toward newer messages.',
          );
          await tester.tap(find.byKey(const Key('ai-coach-question-field')));
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          final keyboardLatest = scroll.position.minScrollExtent;
          expect(scroll.offset, closeTo(keyboardLatest, .5));
          final keyboardDrag = await tester.startGesture(
            tester.getCenter(history),
          );
          for (var i = 0; i < 24; i++) {
            await keyboardDrag.moveBy(const Offset(0, 6));
            // Model the keyboard closing over several layout frames, not one
            // large tester.drag that skips the vulnerable near-latest frames.
            if (i >= 5 && i < 20) {
              tester.view.viewInsets = FakeViewPadding(
                bottom: 300 - (i - 4) * 20,
              );
            }
            await tester.pump(const Duration(milliseconds: 16));
          }
          await keyboardDrag.up();
          await tester.pumpAndSettle();
          expect(scroll.offset - keyboardLatest, greaterThan(72));
          expect(tester.takeException(), isNull);
          await _unmount(tester);
        },
      );
    }
    testWidgets('incoming reply cannot cancel a slow active drag $platform', (
      tester,
    ) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _HeldGateway();
      await _mount(
        tester,
        database: database,
        gateway: gateway,
        gate: true,
        platform: platform,
        historyCount: 35,
      );
      await _send(tester, gateway);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final history = find.byType(ChatHistoryViewport);
      final scroll = tester.widget<ChatHistoryViewport>(history).controller;
      final gesture = await tester.startGesture(tester.getCenter(history));
      for (var i = 0; i < 9; i++) {
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final before = scroll.offset;
      expect(before - scroll.position.minScrollExtent, inExclusiveRange(0, 72));
      expect(scroll.position.isScrollingNotifier.value, isTrue);
      gateway.finish();
      await tester.pumpAndSettle();
      expect(
        scroll.offset,
        closeTo(before, .5),
        reason:
            'A reply must not animate or jump over the user\'s active drag.',
      );
      for (var i = 0; i < 15; i++) {
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scroll.offset, greaterThan(before + 60));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }
}
