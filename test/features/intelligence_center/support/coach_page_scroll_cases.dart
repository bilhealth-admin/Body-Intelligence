part of '../coach_page_lifecycle_regression_test.dart';

void registerCoachScrollCases() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final arabic in [false, true]) {
      testWidgets('slow touch scroll through a long new reply $platform Arabic=$arabic', (
        tester,
      ) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final gateway = _HeldGateway();
        TestGesture? activeGesture;
        try {
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
          final viewport = tester.widget<ChatHistoryViewport>(history);
          final scroll = viewport.controller;
          double latestReadingTarget() =>
              viewport.latestTargetOffset?.call(scroll.position) ??
              scroll.position.minScrollExtent;
          final latest = latestReadingTarget();
          expect(viewport.latestTargetOffset, isNotNull);
          expect(
            latest - scroll.position.minScrollExtent,
            greaterThan(72),
            reason: 'A long answer has a distinct measured reading start.',
          );
          expect(scroll.offset, closeTo(latest, .5));
          // With a reversed viewport, finger-up reads farther down this
          // long answer from its top reading anchor, decreasing the offset.
          final readFurther = await tester.startGesture(
            tester.getCenter(history),
          );
          activeGesture = readFurther;
          for (var i = 0; i < 24; i++) {
            await readFurther.moveBy(const Offset(0, -6));
            await tester.pump(const Duration(milliseconds: 16));
            if (i >= 4) {
              expect(
                scroll.position.isScrollingNotifier.value,
                isTrue,
                reason: 'The reading anchor must not cancel an accepted drag.',
              );
            }
          }
          await readFurther.up();
          activeGesture = null;
          await tester.pumpAndSettle();
          final furtherOffset = scroll.offset;
          expect(
            latest - furtherOffset,
            greaterThan(72),
            reason:
                'A continuous slow drag must leave the reading-start threshold.',
          );
          final returnToStart = await tester.startGesture(
            tester.getCenter(history),
          );
          activeGesture = returnToStart;
          for (var i = 0; i < 16; i++) {
            await returnToStart.moveBy(const Offset(0, 6));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await returnToStart.up();
          activeGesture = null;
          await tester.pumpAndSettle();
          expect(
            scroll.offset,
            greaterThan(furtherOffset + 40),
            reason:
                'The opposite physical drag must return toward the reading start.',
          );
          expect(
            (scroll.offset - latest).abs(),
            lessThan((furtherOffset - latest).abs()),
          );
          await tester.tap(find.byKey(const Key('ai-coach-question-field')));
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          final keyboardLatest = latestReadingTarget();
          expect(scroll.offset, closeTo(keyboardLatest, .5));
          void keyboardTrace(String phase, int step) {
            final position = scroll.position;
            debugPrint(
              'BIL_COACH_KEYBOARD_SCROLL ${jsonEncode({
                'phase': phase, 'step': step,
                'platform': platform.name, 'arabic': arabic,
                'pixels': position.pixels,
                'target': latestReadingTarget(),
                'minimum': position.minScrollExtent,
                'maximum': position.maxScrollExtent,
                'viewport': position.viewportDimension,
                'isScrolling': position.isScrollingNotifier.value,
                // The installed SDK diagnostics include the actual scroll
                // activity without relying on a protected activity getter.
                'position': position.toString(),
              })}',
            );
          }

          keyboardTrace('before_touch', -1);
          final keyboardRect = tester.getRect(history);
          final touchStart = Offset(
            keyboardRect.center.dx,
            keyboardRect.bottom - 24,
          );
          expect(keyboardRect.contains(touchStart), isTrue);
          expect(
            touchStart.dy - 60 * 6,
            greaterThanOrEqualTo(0),
            reason: 'The whole slow touch stays within the physical screen.',
          );
          final keyboardDrag = await tester.startGesture(touchStart);
          activeGesture = keyboardDrag;
          // 135 proved 40 steps moved 211px while viewport geometry moved
          // the reading target 219px. Continue on the final geometry rather
          // than weakening the 72px escape requirement or changing runtime.
          for (var i = 0; i < 60; i++) {
            final beforeStep = scroll.offset;
            await keyboardDrag.moveBy(const Offset(0, -6));
            // Preserve the vulnerable slow frames during keyboard closing.
            // Continue this same gesture after closing: a shrinking maximum
            // may legitimately clamp the earlier near-top offset, so final
            // escape is compared to the measured target of the final viewport.
            if (i >= 5 && i < 20) {
              tester.view.viewInsets = FakeViewPadding(
                bottom: 300 - (i - 4) * 20,
              );
            }
            await tester.pump(const Duration(milliseconds: 16));
            if (const {
              0,
              4,
              5,
              10,
              15,
              19,
              20,
              25,
              30,
              39,
              40,
              50,
              59,
            }.contains(i)) {
              keyboardTrace('touch_frame', i);
            }
            if (i >= 4) {
              expect(
                scroll.position.toString(),
                contains('DragScrollActivity'),
                reason:
                    'An accepted touch remains a real drag during keyboard metrics.',
              );
              expect(
                scroll.position.isScrollingNotifier.value,
                isTrue,
                reason: 'Keyboard metrics must not cancel the accepted touch.',
              );
            }
            if (i >= 5) {
              expect(
                scroll.offset,
                closeTo(beforeStep - 6, .5),
                reason:
                    'Each accepted six-pixel touch moves the actual history without a pin or jump.',
              );
            }
          }
          keyboardTrace('before_up', 60);
          await keyboardDrag.up();
          activeGesture = null;
          await tester.pumpAndSettle();
          keyboardTrace('settled', 60);
          expect(
            latestReadingTarget() - scroll.offset,
            greaterThan(72),
            reason: 'Reading can still leave latest after the keyboard closes.',
          );
          expect(tester.takeException(), isNull);
        } finally {
          final unfinishedGesture = activeGesture;
          if (unfinishedGesture != null) await unfinishedGesture.up();
          for (final pending in gateway.replies) {
            if (!pending.isCompleted) {
              pending.complete(
                LocalModelResult.answer(
                  LocalModelAnswer(
                    text: 'Synthetic fixture cancelled.',
                    action: null,
                  ),
                ),
              );
            }
          }
          try {
            await _unmount(tester);
          } finally {
            await tester.runAsync(database.close);
          }
        }
      });
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
