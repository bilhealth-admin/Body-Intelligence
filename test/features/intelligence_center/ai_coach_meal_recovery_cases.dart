part of 'ai_coach_tool_execution_behavior_test.dart';

void _coachMealRecoveryCases() {
  testWidgets(
    'Coach restores a durable meal Undo after remount without replaying a write',
    (tester) async {
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
        final item = await database.select(database.mealItems).getSingle();
        final original = (await _structuredMealReceipts(preferences)).single;
        await _disposeCoach(tester);
        await mount();
        expect(await MealRepository(database).getMealItem(item.id), item);
        expect(gateway.calls, 1);
        expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
        await _tapLatestUndo(tester);
        await _waitForStoredReceipts(tester, preferences, minimumCount: 2);
        final receipts = await _structuredMealReceipts(preferences);
        final compensated = await MealRepository(database).getMealItem(item.id);
        expect(compensated.deletedAt, isNotNull);
        expect(compensated.revision, item.revision + 1);
        expect(receipts.last['operation_id'], original['operation_id']);
        expect(receipts.last['undone_at'], isNotNull);
        expect(gateway.calls, 1);
        await _disposeCoach(tester);
        await mount();
        expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
        expect(
          await MealRepository(database).getMealItem(item.id),
          compensated,
        );
        expect(gateway.calls, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeCoach(tester);
      }
    },
  );

  for (final invalidation in ['later revision', 'wrong digest', 'wrong tool']) {
    testWidgets(
      'Coach durable meal recovery rejects $invalidation without a write',
      (tester) async {
        await _setPhoneSurface(tester);
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = MealRepository(database);
        final preferences = PreferencesRepository(database);
        final saved = await repository.commitCoachMeal(
          command: CoachMealCommand.quickMacros(
            operationId: 'recovery-$invalidation'.replaceAll(' ', '-'),
            date: DateTime(2026, 9, 5),
            mealType: 'lunch',
            calories: 1905,
          ),
          scope: CoachMealOwnerScope(ownerId: null, isCurrent: () => true),
        );
        final payload = _recoveryMealReceiptPayload(saved);
        if (invalidation == 'later revision') {
          await repository.updateMealItem(
            id: saved.after.single.item.id,
            quantity: 2,
          );
        } else if (invalidation == 'wrong digest') {
          (payload['after']! as Map)['arguments_digest'] = 'not-the-command';
        } else {
          payload['tool_id'] = 'delete_meal_item';
        }
        await preferences.set(
          'intelligenceConversationV1',
          jsonEncode([_recoveryMealMessage(payload)]),
        );
        final before = await database.select(database.mealItems).getSingle();
        final gateway = _QueuedToolGateway([]);
        try {
          await tester.pumpWidget(
            _coachApp(
              database: database,
              gateway: gateway,
              settingsService: AppSettingsService(
                store: _MemorySettingsStore(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Persisted meal receipt'), findsOneWidget);
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
          await _tapLatestUndo(tester);
          expect(
            find.text('There is no recent reversible action.'),
            findsOneWidget,
          );
          expect(await database.select(database.mealItems).getSingle(), before);
          expect(gateway.calls, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await _disposeCoach(tester);
        }
      },
    );
  }

  testWidgets(
    'Coach cannot recover another owner meal Undo from a copied transcript',
    (tester) async {
      await _setPhoneSurface(tester);
      final a = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      );
      final b = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-b',
      );
      addTearDown(a.close);
      addTearDown(b.close);
      final command = CoachMealCommand.quickMacros(
        operationId: 'same-operation-id-different-owner',
        date: DateTime(2026, 9, 5),
        mealType: 'lunch',
        calories: 1905,
      );
      final saved = await MealRepository(a).commitCoachMeal(
        command: command,
        scope: CoachMealOwnerScope(ownerId: 'owner-a', isCurrent: () => true),
      );
      await MealRepository(b).addQuickMacroEntry(
        date: DateTime(2026, 9, 5),
        mealType: 'lunch',
        calories: 1905,
        protein: 0,
        carbohydrates: 0,
        fat: 0,
        caloriesKnown: true,
        proteinKnown: false,
        carbohydratesKnown: false,
        fatKnown: false,
      );
      final bItem = await b.select(b.mealItems).getSingle();
      expect(bItem.id, saved.after.single.item.id);
      await PreferencesRepository(b).set(
        'intelligenceConversationV1',
        jsonEncode([_recoveryMealMessage(_recoveryMealReceiptPayload(saved))]),
      );
      final gateway = _QueuedToolGateway([]);
      try {
        await tester.pumpWidget(
          _coachApp(
            database: b,
            gateway: gateway,
            settingsService: AppSettingsService(store: _MemorySettingsStore()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Persisted meal receipt'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
        await _tapLatestUndo(tester);
        expect(await b.select(b.mealItems).getSingle(), bItem);
        expect(
          await a.select(a.mealItems).getSingle(),
          saved.after.single.item,
        );
        expect(gateway.calls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeCoach(tester);
      }
    },
  );

  testWidgets(
    'Coach meal Undo follows the selected conversation and revalidates on return',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final saved = await _seedRecoverableMeal(database);
      final preferences = PreferencesRepository(database);
      await preferences.set(
        'intelligenceConversationActiveIdV1',
        'meal-history',
      );
      final gateway = _QueuedToolGateway([]);
      try {
        await tester.pumpWidget(
          _coachApp(
            database: database,
            gateway: gateway,
            settingsService: AppSettingsService(store: _MemorySettingsStore()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('ai-coach-conversation-history-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'New conversation'));
        await tester.pumpAndSettle();
        expect(find.text('Persisted meal receipt'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
        await _tapLatestUndo(tester);
        expect(
          find.text('There is no recent reversible action.'),
          findsOneWidget,
        );
        expect(
          await database.select(database.mealItems).getSingle(),
          saved.after.single.item,
        );
        await tester.tap(
          find.byKey(const Key('ai-coach-conversation-history-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('ai-coach-conversation-meal-history')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Persisted meal receipt'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
        await _tapLatestUndo(tester);
        final item = await database.select(database.mealItems).getSingle();
        expect(item.deletedAt, isNotNull);
        expect(item.revision, saved.after.single.item.revision + 1);
        expect(gateway.calls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeCoach(tester);
      }
    },
  );

  testWidgets(
    'Coach recovered meal Undo permanently cancels on delivered owner A B A',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      );
      addTearDown(database.close);
      final saved = await _seedRecoverableMeal(database);
      final changes = StreamController<String?>.broadcast(sync: true);
      addTearDown(changes.close);
      String? owner = 'owner-a';
      final gateway = _QueuedToolGateway([]);
      try {
        await tester.pumpWidget(
          _coachApp(
            database: database,
            gateway: gateway,
            settingsService: AppSettingsService(store: _MemorySettingsStore()),
            ownerWitness: CoachNativeOwnerWitness(
              readOwner: () => owner,
              changes: changes.stream,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
        owner = 'owner-b';
        changes.add(owner);
        owner = 'owner-a';
        changes.add(owner);
        await _tapLatestUndo(tester);
        expect(
          find.text('The account changed. Reopen AI Coach and try again.'),
          findsOneWidget,
        );
        expect(find.text('The previous action was undone.'), findsNothing);
        expect(
          await database.select(database.mealItems).getSingle(),
          saved.after.single.item,
        );
        expect(gateway.calls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeCoach(tester);
      }
    },
  );
}

Future<CoachMealCommit> _seedRecoverableMeal(AppDatabase database) async {
  final result = await MealRepository(database).commitCoachMeal(
    command: CoachMealCommand.quickMacros(
      operationId: 'recoverable-meal-history',
      date: DateTime(2026, 9, 5),
      mealType: 'lunch',
      calories: 1905,
    ),
    scope: CoachMealOwnerScope(
      ownerId: database.localOwnerId,
      isCurrent: () => true,
    ),
  );
  await PreferencesRepository(database).set(
    'intelligenceConversationV1',
    jsonEncode([_recoveryMealMessage(_recoveryMealReceiptPayload(result))]),
  );
  return result;
}

Map<String, Object?> _recoveryMealReceiptPayload(CoachMealCommit result) => {
  'action_id': 'historical-proposal',
  'operation_id': result.operationId,
  'tool_id': result.toolId,
  'committed': true,
  'verified': true,
  'source': 'ai_coach',
  'completed_at': result.committedAt.toIso8601String(),
  'entity_type': 'meal_item',
  'entity_id': result.after.single.item.id.toString(),
  'before': result.beforePayload,
  'after': result.afterPayload,
  'undoable': true,
};

Map<String, Object?> _recoveryMealMessage(Map<String, Object?> receipt) => {
  'id': 'tool-restored-meal-receipt',
  'role': 'bil',
  'kind': 'action',
  'text': 'Persisted meal receipt',
  'createdAt': '2026-09-05T10:00:00.000',
  'evidence': ['BIL verified tool result', jsonEncode(receipt)],
};
