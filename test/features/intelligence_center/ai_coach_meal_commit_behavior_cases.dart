part of 'ai_coach_tool_execution_behavior_test.dart';

void _coachMealCommitBehaviorCases() {
  testWidgets(
    'Coach protein-only readback keeps calories and other macros unknown',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _QueuedToolGateway([
        _tool('quick_add_macros', {
          'date': '2026-09-05',
          'mealType': 'lunch',
          'protein': 30,
        }),
      ]);
      try {
        await tester.pumpWidget(
          _coachApp(
            database: database,
            gateway: gateway,
            settingsService: AppSettingsService(store: _MemorySettingsStore()),
          ),
        );
        await tester.pumpAndSettle();
        await _submitNextTool(
          tester,
          type: IntelligenceActionType.quickAddMacros,
          id: 'quick_add_macros',
          expectedReceipt: 'Macro entry saved. Calories are unknown.',
        );
        final saved = await database.select(database.mealItems).getSingle();
        final preferences = PreferencesRepository(database);
        await _waitForStoredReceipts(tester, preferences, minimumCount: 1);
        final committed = (await _structuredMealReceipts(preferences)).single;
        expect(committed['entity_id'], saved.id.toString());
        final item =
            ((committed['after'] as Map)['items'] as List).single as Map;
        expect(item['item_uuid'], saved.uuid);
        expect(item['revision'], saved.revision);
        expect(item['calories'], isNull);
        expect(item['protein'], 30);
        expect(item['carbohydrates'], isNull);
        expect(item['fat'], isNull);
        final ledger = await DailyLogRepository(
          database,
        ).readLedger(DateTime(2026, 9, 5));
        expect(ledger.calories, isNull);
        expect(ledger.protein, 30);
        expect(ledger.carbohydrates, isNull);
        expect(ledger.fat, isNull);
        expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeCoach(tester);
      }
    },
  );

  testWidgets(
    'Coach calorie-only receipt and Undo come from the durable item readback',
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
      try {
        await tester.pumpWidget(
          _coachApp(
            database: database,
            gateway: gateway,
            settingsService: AppSettingsService(store: _MemorySettingsStore()),
          ),
        );
        await tester.pumpAndSettle();
        await _submitNextTool(
          tester,
          type: IntelligenceActionType.quickAddMacros,
          id: 'quick_add_macros',
          expectedReceipt:
              'Calorie-only entry saved. Other nutrients are unknown.',
        );
        final saved = await database.select(database.mealItems).getSingle();
        final preferences = PreferencesRepository(database);
        await _waitForStoredReceipts(tester, preferences, minimumCount: 1);
        var receipts = await _structuredMealReceipts(preferences);
        expect(receipts, hasLength(1));
        final committed = receipts.single;
        expect(committed['operation_id'], isA<String>());
        expect(committed['tool_id'], 'quick_add_macros');
        expect(committed['entity_type'], 'meal_item');
        expect(committed['entity_id'], saved.id.toString());
        final after = (committed['after'] as Map)['items'] as List;
        expect((after.single as Map)['item_uuid'], saved.uuid);
        expect((after.single as Map)['revision'], saved.revision);
        expect((after.single as Map)['calories'], 1905);
        expect((after.single as Map)['protein'], isNull);
        expect((after.single as Map)['carbohydrates'], isNull);
        expect((after.single as Map)['fat'], isNull);
        final ledger = await DailyLogRepository(
          database,
        ).readLedger(DateTime(2026, 9, 5));
        expect(ledger.calories, 1905);
        expect(ledger.protein, isNull);

        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Undo').last,
        );
        button.onPressed!();
        button.onPressed!();
        await tester.pumpAndSettle();
        await _waitForStoredReceipts(tester, preferences, minimumCount: 2);
        receipts = await _structuredMealReceipts(preferences);
        expect(receipts, hasLength(2));
        final undo = receipts.last;
        expect(undo['operation_id'], committed['operation_id']);
        expect(undo['undone_at'], isNotNull);
        final undoneItem = await MealRepository(database).getMealItem(saved.id);
        expect(undoneItem.revision, saved.revision + 1);
        expect(undoneItem.deletedAt, isNotNull);
        final undoneAfter = (undo['after'] as Map)['items'] as List;
        expect((undoneAfter.single as Map)['revision'], undoneItem.revision);
        expect((undoneAfter.single as Map)['deleted'], isTrue);
        expect(find.text('The previous action was undone.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeCoach(tester);
      }
    },
  );

  testWidgets(
    'Coach meal prepared before confirmation rejects a later item revision',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final meals = MealRepository(database);
      final mealId = await meals.addQuickMacroEntry(
        date: DateTime(2026, 9, 5),
        mealType: 'lunch',
        calories: 100,
        protein: 0,
        carbohydrates: 0,
        fat: 0,
        caloriesKnown: true,
        proteinKnown: false,
        carbohydratesKnown: false,
        fatKnown: false,
      );
      final original = await database.select(database.mealItems).getSingle();
      final gateway = _QueuedToolGateway([
        _tool('update_meal_item', {'itemId': original.id, 'quantityGrams': 2}),
      ]);
      try {
        await tester.pumpWidget(
          _coachApp(
            database: database,
            gateway: gateway,
            settingsService: AppSettingsService(store: _MemorySettingsStore()),
          ),
        );
        await tester.pumpAndSettle();
        await _openNextToolAction(
          tester,
          type: IntelligenceActionType.updateMealItem,
          id: 'update_meal_item',
        );
        await _pumpUntil(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
        );
        await meals.updateMealItem(id: original.id, quantity: 3);
        final latest = await meals.getMealItem(original.id);
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();
        expect(await meals.getMealItem(original.id), latest);
        expect(latest.mealId, mealId);
        expect(
          find.text(
            'This meal changed since the action was prepared. Review it again.',
          ),
          findsOneWidget,
        );
        expect(
          await _structuredMealReceipts(PreferencesRepository(database)),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeCoach(tester);
      }
    },
  );

  testWidgets(
    'Coach meal owner witness permanently cancels delivered A B A while confirming',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      );
      addTearDown(database.close);
      String? owner = 'owner-a';
      final changes = StreamController<String?>.broadcast(sync: true);
      addTearDown(changes.close);
      final gateway = _QueuedToolGateway([
        _tool('quick_add_macros', {
          'date': '2026-09-05',
          'mealType': 'lunch',
          'calories': 1905,
        }),
      ]);
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
        await _openNextToolAction(
          tester,
          type: IntelligenceActionType.quickAddMacros,
          id: 'quick_add_macros',
        );
        await _pumpUntil(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
        );
        owner = 'owner-b';
        changes.add(owner);
        owner = 'owner-a';
        changes.add(owner);
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();
        expect(await database.select(database.mealItems).get(), isEmpty);
        expect(await database.select(database.meals).get(), isEmpty);
        expect(
          await _structuredMealReceipts(PreferencesRepository(database)),
          isEmpty,
        );
        expect(
          find.text('The account changed. Reopen AI Coach and try again.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeCoach(tester);
      }
    },
  );

  testWidgets(
    'Coach stale Undo preserves later data and shows no success receipt',
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
      try {
        await tester.pumpWidget(
          _coachApp(
            database: database,
            gateway: gateway,
            settingsService: AppSettingsService(store: _MemorySettingsStore()),
          ),
        );
        await tester.pumpAndSettle();
        await _submitNextTool(
          tester,
          type: IntelligenceActionType.quickAddMacros,
          id: 'quick_add_macros',
          expectedReceipt:
              'Calorie-only entry saved. Other nutrients are unknown.',
        );
        final item = await database.select(database.mealItems).getSingle();
        await MealRepository(database).updateMealItem(id: item.id, quantity: 2);
        final later = await MealRepository(database).getMealItem(item.id);
        await _tapLatestUndo(tester);
        expect(await MealRepository(database).getMealItem(item.id), later);
        expect(find.text('The previous action was undone.'), findsNothing);
        expect(
          find.text(
            'This meal changed since the action was prepared. Review it again.',
          ),
          findsOneWidget,
        );
        final receipts = await _structuredMealReceipts(
          PreferencesRepository(database),
        );
        expect(receipts, hasLength(1));
        expect(receipts.single.containsKey('undone_at'), isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeCoach(tester);
      }
    },
  );

  testWidgets(
    'Coach quick macro Undo preserves the older food in its reused meal',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final meals = MealRepository(database);
      final day = DateTime(2026, 9, 5);
      final foodId = await FoodRepository(database).addFood(
        name: 'Lunch recorded earlier',
        category: 'grain',
        servingSize: 100,
        servingUnit: 'g',
        calories: 380,
        protein: 13,
        carbs: 68,
        fats: 7,
      );
      final lunchId = await meals.createMeal(
        date: day,
        name: 'lunch',
        type: 'lunch',
      );
      await meals.addMealItem(mealId: lunchId, foodId: foodId, quantity: 100);
      final older = await database.select(database.mealItems).getSingle();
      final gateway = _QueuedToolGateway(<Map<String, Object?>>[
        _tool('quick_add_macros', <String, Object?>{
          'date': '2026-09-05',
          'mealType': 'lunch',
          'calories': 420,
          'protein': 35,
          'carbohydrates': 40,
          'fat': 12,
        }),
      ]);
      try {
        await tester.pumpWidget(
          _coachApp(
            database: database,
            gateway: gateway,
            settingsService: AppSettingsService(store: _MemorySettingsStore()),
          ),
        );
        await tester.pumpAndSettle();
        await _submitNextTool(
          tester,
          type: IntelligenceActionType.quickAddMacros,
          id: 'quick_add_macros',
          expectedReceipt: 'Quick macros added to lunch: 420 kcal.',
        );
        expect(
          (await meals.watchMealsForDate(day).first).single.items,
          hasLength(2),
        );

        await _tapLatestUndo(tester);

        final after = await meals.watchMealsForDate(day).first;
        expect(after, hasLength(1));
        expect(after.single.meal.id, lunchId);
        expect(after.single.items, [older]);
        expect(await meals.getMealItem(older.id), older);
      } finally {
        await _disposeCoach(tester);
      }
    },
  );
}

Future<List<Map<String, dynamic>>> _structuredMealReceipts(
  PreferencesRepository preferences,
) async {
  final raw = await preferences.get('intelligenceConversationV1');
  if (raw == null) return [];
  final result = <Map<String, dynamic>>[];
  for (final message in (jsonDecode(raw) as List).whereType<Map>()) {
    for (final evidence
        in (message['evidence'] as List? ?? []).whereType<String>()) {
      if (!evidence.startsWith('{')) continue;
      final data = jsonDecode(evidence);
      if (data is Map<String, dynamic> && data['entity_type'] == 'meal_item') {
        result.add(data);
      }
    }
  }
  return result;
}
