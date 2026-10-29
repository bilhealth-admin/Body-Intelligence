part of '../coach_page_lifecycle_regression_test.dart';

void registerCoachCaretIdleCases() {
  for (final arabic in [false, true]) {
    testWidgets(
      'focused Coach draft rests between visible caret blinks arabic=$arabic',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final gateway = _HeldGateway();
        try {
          await _mount(
            tester,
            database: database,
            gateway: gateway,
            arabic: arabic,
            platform: TargetPlatform.iOS,
          );
          await _presentationPageReady(tester);
          final field = find.byKey(const Key('ai-coach-question-field'));
          final draft = arabic
              ? 'هذه مسودة طويلة غير مرسلة لاختبار بقاء مؤشر الكتابة واضحًا دون رسم متواصل.'
              : 'This is a long unsent draft for checking a visible caret without continuous drawing.';
          await tester.tap(field);
          await tester.enterText(field, draft);
          // Let focus/container/scroll transitions finish across real build
          // boundaries before observing a settled draft. A single large pump
          // can start a newly-built transition at its final fake-clock instant.
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
          final editable = find.descendant(
            of: field,
            matching: find.byType(EditableText),
          );
          final input = tester.widget<EditableText>(editable);
          expect(input.focusNode.hasFocus, isTrue);
          final state = tester.state<EditableTextState>(editable);
          final visibility = <bool>{state.cursorCurrentlyVisible};
          var scheduledFrames = 0;
          var maximumActiveTickers = 0;
          // Count actual frames scheduled by the real mounted page, rather than
          // treating explicit tester pumps as production frame requests. No send,
          // reply reveal, voice capture or selection animation is active here.
          for (var frame = 0; frame < 125; frame++) {
            if (tester.binding.hasScheduledFrame) scheduledFrames++;
            final tickers = tester.binding.transientCallbackCount;
            if (tickers > maximumActiveTickers) maximumActiveTickers = tickers;
            await tester.pump(const Duration(milliseconds: 16));
            visibility.add(state.cursorCurrentlyVisible);
          }
          debugPrint(
            'BIL_COACH_DRAFT_IDLE arabic=$arabic scheduled=$scheduledFrames/125 '
            'maxTickers=$maximumActiveTickers caretStates=$visibility',
          );
          expect(
            scheduledFrames,
            lessThanOrEqualTo(8),
            reason: 'A static focused draft should rest between caret phases.',
          );
          expect(maximumActiveTickers, 0);
          expect(visibility, {false, true}, reason: 'The caret still blinks.');
          expect(input.controller.text, draft);
          expect(input.focusNode.hasFocus, isTrue);
          expect(input.controller.selection.isCollapsed, isTrue);
          expect(input.controller.selection.extentOffset, draft.length);
          expect(gateway.calls, 0, reason: 'Typing must not submit the draft.');
          input.focusNode.unfocus();
          await tester.pumpAndSettle();
          expect(input.controller.text, draft);
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        } finally {
          // Even the intentionally failing before case must retire subscribers
          // before closing SQLite; its native completion needs real async I/O.
          await _unmount(tester);
          await tester.runAsync(database.close);
        }
      },
    );
  }
}
