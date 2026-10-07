part of 'ai_coach_tool_execution_behavior_test.dart';

void _coachUndoPermissionCases() {
  for (final restored in [false, true]) {
    testWidgets('meal Undo respects shield after commit restored=$restored', (
      tester,
    ) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _QueuedToolGateway([
        _tool('quick_add_macros', {
          'date': '2026-09-05',
          'mealType': 'lunch',
          'calories': 1905,
        }),
      ]);
      final settings = AppSettingsService(store: _MemorySettingsStore());
      final preferences = PreferencesRepository(database);
      Future<void> mount() async {
        await tester.pumpWidget(
          _coachApp(
            database: database,
            gateway: gateway,
            settingsService: settings,
          ),
        );
        await tester.pumpAndSettle();
      }

      try {
        await mount();
        await _submitNextTool(
          tester,
          type: IntelligenceActionType.quickAddMacros,
          id: 'quick_add_macros',
          expectedReceipt:
              'Calorie-only entry saved. Other nutrients are unknown.',
        );
        await _waitForStoredReceipts(tester, preferences, minimumCount: 1);
        if (restored) {
          await _disposeCoach(tester);
          await mount();
        }
        final item = await database.select(database.mealItems).getSingle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(IntelligenceCenterPage)),
        );
        container.read(coachActionPermissionModeProvider.notifier).state =
            CoachActionPermissionMode.readOnly;
        await tester.pump();
        ScaffoldMessenger.of(
          tester.element(find.byType(IntelligenceCenterPage)),
        ).clearSnackBars();
        await tester.pumpAndSettle();
        await _tapLatestUndo(tester);
        expect(
          find.text(
            'This action needs write permission. Change the shield setting to continue.',
          ),
          findsOneWidget,
        );
        expect(await database.select(database.mealItems).getSingle(), item);
        expect(await _structuredMealReceipts(preferences), hasLength(1));
        expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
        container.read(coachActionPermissionModeProvider.notifier).state =
            CoachActionPermissionMode.askBeforeWrite;
        await tester.pump();
        ScaffoldMessenger.of(
          tester.element(find.byType(IntelligenceCenterPage)),
        ).clearSnackBars();
        await tester.pumpAndSettle();
        await _tapLatestUndo(tester);
        await _waitForStoredReceipts(tester, preferences, minimumCount: 2);
        final undone = await database.select(database.mealItems).getSingle();
        expect(undone.deletedAt, isNotNull);
        expect(undone.revision, item.revision + 1);
        expect(gateway.calls, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeCoach(tester);
      }
    });
  }
}
