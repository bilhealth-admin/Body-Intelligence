part of '../coach_page_lifecycle_regression_test.dart';

void registerCoachAccessibilityCases() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final arabic in [false, true]) {
      testWidgets(
        'Coach layout: $platform Arabic=$arabic large text and keyboard',
        (tester) async {
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          await _mount(
            tester,
            database: database,
            gateway: _HeldGateway(),
            platform: platform,
            arabic: arabic,
            textScale: 2,
            size: const Size(320, 700),
            historyCount: 35,
          );
          expect(tester.takeException(), isNull);
          for (final finder in [
            find.byTooltip(arabic ? 'رجوع' : 'Back'),
            find.byKey(const Key('ai-coach-hero-start')),
            find.byKey(const Key('ai-coach-conversation-history-button')),
          ]) {
            final size = tester.getSize(finder);
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
          await tester.tap(find.byKey(const Key('ai-coach-question-field')));
          tester.view.viewInsets = const FakeViewPadding(bottom: 250);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .getBottomLeft(find.byKey(const Key('ai-coach-question-field')))
                .dy,
            lessThanOrEqualTo(450),
          );
          await tester.tap(
            find.byTooltip(arabic ? 'أدوات المدرب' : 'Coach controls'),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final clear = find.text(
            arabic ? 'مسح المحادثة' : 'Clear conversation',
          );
          await tester.ensureVisible(clear);
          await tester.pumpAndSettle();
          expect(clear.hitTestable(), findsOneWidget);
          await _unmount(tester);
        },
      );
    }
  }

  testWidgets('restored history ends with its reply, not a new welcome', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final router = await _mount(
      tester,
      database: database,
      gateway: _HeldGateway(),
      historyCount: 8,
    );
    expect(find.textContaining('Good morning'), findsNothing);
    expect(
      find.byKey(const ValueKey('coach-message-text-fixture-7')).hitTestable(),
      findsOneWidget,
    );
    router.go('/dashboard');
    await tester.pumpAndSettle();
    router.go('/intelligence-center');
    await tester.pumpAndSettle();
    expect(find.textContaining('Good morning'), findsNothing);
    expect(
      find.byKey(const ValueKey('coach-message-text-fixture-7')).hitTestable(),
      findsOneWidget,
    );
    await _unmount(tester);
  });

  testWidgets(
    'welcome and user move above the newest reply, including a long reply',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _HeldGateway();
      await _mount(tester, database: database, gateway: gateway);
      await _send(tester, gateway);
      gateway.finish();
      await tester.pumpAndSettle();
      final greeting = find.textContaining('Good morning');
      final user = find.text('hi');
      final response = find.text('A completed local fixture response.');
      expect(
        tester.getTopLeft(greeting).dy,
        lessThan(tester.getTopLeft(user).dy),
      );
      expect(
        tester.getTopLeft(user).dy,
        lessThan(tester.getTopLeft(response).dy),
      );
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView).first)
          .controller!;
      expect(scroll.offset, closeTo(scroll.position.minScrollExtent, .5));
      await tester.enterText(
        find.byKey(const Key('ai-coach-question-field')),
        'hi',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai-coach-send-button')));
      for (var i = 0; gateway.calls < 2 && i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(gateway.calls, 2);
      gateway.finish(
        index: 1,
        text: List.filled(60, 'A long reply with details.').join('\n'),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(scroll.position.minScrollExtent, .5));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(scroll.offset - scroll.position.minScrollExtent, greaterThan(72));
      expect(find.byKey(const ValueKey('chat-jump-to-latest')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );
}
