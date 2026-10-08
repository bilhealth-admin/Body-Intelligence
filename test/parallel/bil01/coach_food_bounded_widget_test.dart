import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/bil_action_receipt.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_admission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/food_flow/coach_food_flow.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_receipt_card.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_review_card.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BIL-01 bounded native Food widgets', () {
    testWidgets(
      'log_foods review -> confirm -> transaction/readback -> verified receipt',
      (tester) async {
        final f = _WidgetFixture();
        addTearDown(f.close);
        await f.seed('Rice', calories: 130, protein: 2.5, carbs: 28, fat: .3);
        await f.seed('Chicken', calories: 165, protein: 31, carbs: 0, fat: 3.6);
        final draft = await f.draft(
          'اكلت 100غ Rice و 200غ Chicken غداء اليوم',
          DateTime(2026, 10, 7, 13, 15),
        );
        expect(draft.kind, CoachFoodDraftKind.logFoods);
        expect(draft.review.items, hasLength(2));

        var mode = CoachActionPermissionMode.askBeforeWrite;
        var current = true;
        final scope = CoachMealOwnerScope(
          ownerId: f.db.localOwnerId,
          isCurrent: () => current,
        );
        await tester.pumpWidget(
          _app(
            _FoodTransactionHarness(
              draft: draft,
              db: f.db,
              meals: f.meals,
              scope: scope,
              permissionMode: () => mode,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CoachFoodReviewCard), findsOneWidget);
        expect(await f.db.select(f.db.meals).get(), isEmpty);
        expect(await f.db.select(f.db.mealItems).get(), isEmpty);

        await tester.tap(
          find.byKey(CoachFoodCardKeys.confirm(draft.operationId)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CoachFoodReceiptCard), findsOneWidget);
        expect(
          find.byKey(CoachFoodCardKeys.receipt(draft.operationId)),
          findsOneWidget,
        );
        expect(await f.db.select(f.db.meals).get(), hasLength(1));
        expect(await f.db.select(f.db.mealItems).get(), hasLength(2));
        expect(tester.takeException(), isNull);

        // Keep the captured witnesses alive long enough to prove no implicit
        // write happens merely because the widget rebuilds.
        mode = CoachActionPermissionMode.readOnly;
        current = false;
        await tester.pump();
        expect(await f.db.select(f.db.mealItems).get(), hasLength(2));
      },
    );

    testWidgets('permission revoked after review blocks persistence', (
      tester,
    ) async {
      final f = _WidgetFixture();
      addTearDown(f.close);
      await f.seed('Rice', calories: 130, protein: 2.5, carbs: 28, fat: .3);
      final draft = await f.draft(
        'اكلت 100غ Rice غداء اليوم',
        DateTime(2026, 10, 7, 13),
      );
      var mode = CoachActionPermissionMode.askBeforeWrite;
      final scope = CoachMealOwnerScope(
        ownerId: f.db.localOwnerId,
        isCurrent: () => true,
      );
      await tester.pumpWidget(
        _app(
          _FoodTransactionHarness(
            draft: draft,
            db: f.db,
            meals: f.meals,
            scope: scope,
            permissionMode: () => mode,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CoachFoodReviewCard), findsOneWidget);
      mode = CoachActionPermissionMode.readOnly;
      await tester.tap(
        find.byKey(CoachFoodCardKeys.confirm(draft.operationId)),
      );
      await tester.pumpAndSettle();
      expect(await f.db.select(f.db.meals).get(), isEmpty);
      expect(await f.db.select(f.db.mealItems).get(), isEmpty);
      expect(find.byType(CoachFoodReceiptCard), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('owner A -> B -> A permanently cancels an open review', (
      tester,
    ) async {
      final f = _WidgetFixture();
      addTearDown(f.close);
      await f.seed('Rice', calories: 130, protein: 2.5, carbs: 28, fat: .3);
      final draft = await f.draft(
        'اكلت 100غ Rice غداء اليوم',
        DateTime(2026, 10, 7, 13),
      );
      var current = true;
      final scope = CoachMealOwnerScope(
        ownerId: f.db.localOwnerId,
        isCurrent: () => current,
      );
      await tester.pumpWidget(
        _app(
          _FoodTransactionHarness(
            draft: draft,
            db: f.db,
            meals: f.meals,
            scope: scope,
            permissionMode: () => CoachActionPermissionMode.askBeforeWrite,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(CoachFoodCardKeys.confirm(draft.operationId)),
        findsOneWidget,
      );

      current = false;
      // Observe the owner transition while the review is still open, exactly
      // like the production auth-state subscription does. Once cancelled, a
      // later A -> B -> A transition must never reactivate this scope.
      expect(scope.isCurrent, isFalse);
      await tester.pump();
      current = true;
      await tester.pumpAndSettle();
      // The stale card may still be painted until an interaction/rebuild, but
      // the latched scope must refuse the callback permanently.
      await tester.tap(
        find.byKey(CoachFoodCardKeys.confirm(draft.operationId)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(CoachFoodCardKeys.confirm(draft.operationId)),
        findsNothing,
      );
      expect(await f.db.select(f.db.meals).get(), isEmpty);
      expect(await f.db.select(f.db.mealItems).get(), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'replace_meal_item review commits frozen correction to the same item identity',
      (tester) async {
        final f = _WidgetFixture();
        addTearDown(f.close);
        await f.seed('Rice', calories: 130, protein: 2.5, carbs: 28, fat: .3);
        final initial = await f.draft(
          'اكلت 100غ Rice غداء اليوم',
          DateTime(2026, 10, 7, 13),
        );
        final initialCommit = await f.meals.commitCoachMeal(
          command: _command(initial),
          scope: CoachMealOwnerScope(
            ownerId: f.db.localOwnerId,
            isCurrent: () => true,
          ),
        );
        final before = initialCommit.after.single.item;
        final correction = await f.draft(
          'نصها',
          DateTime(2026, 10, 7, 13, 2),
          preferredTargetItemId: before.id,
        );
        expect(correction.kind, CoachFoodDraftKind.replaceMealItem);

        final scope = CoachMealOwnerScope(
          ownerId: f.db.localOwnerId,
          isCurrent: () => true,
        );
        await tester.pumpWidget(
          _app(
            _FoodTransactionHarness(
              draft: correction,
              db: f.db,
              meals: f.meals,
              scope: scope,
              permissionMode: () => CoachActionPermissionMode.askBeforeWrite,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CoachFoodReviewCard), findsOneWidget);
        await tester.tap(
          find.byKey(CoachFoodCardKeys.confirm(correction.operationId)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CoachFoodReceiptCard), findsOneWidget);
        final after = await f.meals.getMealItem(before.id);
        expect(after.id, before.id);
        expect(after.uuid, before.uuid);
        expect(after.quantity, 50);
        expect(after.revision, before.revision + 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(splashFactory: NoSplash.splashFactory),
  locale: const Locale('en'),
  home: Scaffold(body: Center(child: child)),
);

final class _FoodTransactionHarness extends StatefulWidget {
  const _FoodTransactionHarness({
    required this.draft,
    required this.db,
    required this.meals,
    required this.scope,
    required this.permissionMode,
  });

  final CoachFoodActionDraft draft;
  final AppDatabase db;
  final MealRepository meals;
  final CoachMealOwnerScope scope;
  final CoachActionPermissionMode Function() permissionMode;

  @override
  State<_FoodTransactionHarness> createState() =>
      _FoodTransactionHarnessState();
}

final class _FoodTransactionHarnessState
    extends State<_FoodTransactionHarness> {
  CoachMealCommit? _commit;
  BilActionReceipt? _receipt;

  @override
  Widget build(BuildContext context) {
    final commit = _commit;
    final receipt = _receipt;
    if (commit != null && receipt != null) {
      return CoachFoodReceiptCard(
        commit: commit,
        receipt: receipt,
        ownerIsCurrent: () => widget.scope.isCurrent,
        onEdit: (_) async {},
        onUndo: () async {},
        onViewDailyLog: () async {},
      );
    }
    return CoachFoodReviewCard(
      review: widget.draft.review,
      operationId: widget.draft.operationId,
      mealType: widget.draft.mealType,
      day: widget.draft.day,
      ownerIsCurrent: () => widget.scope.isCurrent,
      onAdjust: () async {},
      onConfirm: () async {
        final action = _action(widget.draft);
        final binding = const CoachActionAdmission().bind(
          action,
          requireOperationId: true,
        );
        if (binding == null) throw StateError('food_action_not_admitted');
        if (!binding.allows(widget.permissionMode())) {
          throw StateError('food_write_permission_revoked');
        }
        widget.scope.check(widget.db.localOwnerId);
        final committed = await widget.meals.commitCoachMeal(
          command: _command(widget.draft),
          scope: widget.scope,
        );
        widget.scope.check(widget.db.localOwnerId, committed: true);
        final verified = _receiptFor(action.id, committed);
        expect(CoachFoodReceiptBinding.matches(committed, verified), isTrue);
        if (mounted) {
          setState(() {
            _commit = committed;
            _receipt = verified;
          });
        }
      },
    );
  }
}

IntelligenceAction _action(CoachFoodActionDraft draft) => switch (draft.kind) {
  CoachFoodDraftKind.logFoods => IntelligenceAction(
    id: 'bounded-log-foods',
    toolId: 'log_foods',
    operationId: draft.operationId,
    type: IntelligenceActionType.logFoods,
    label: 'Review and save foods',
    requiresConfirmation: true,
    payload: draft.payload,
  ),
  CoachFoodDraftKind.replaceMealItem => IntelligenceAction(
    id: 'bounded-replace-meal-item',
    toolId: 'replace_meal_item',
    operationId: draft.operationId,
    type: IntelligenceActionType.replaceMealItem,
    label: 'Review food correction',
    requiresConfirmation: true,
    payload: draft.payload,
  ),
};

CoachMealCommand _command(CoachFoodActionDraft draft) => switch (draft.kind) {
  CoachFoodDraftKind.logFoods => CoachMealCommand.foods(
    operationId: draft.operationId,
    date: draft.day,
    mealType: draft.mealType,
    review: draft.review,
    occurredAt: DateTime.parse(draft.payload['occurredAt']! as String),
  ),
  CoachFoodDraftKind.replaceMealItem => CoachMealCommand.replaceFood(
    operationId: draft.operationId,
    expected: CoachMealItemVersion(
      id: (draft.payload['expected']! as Map)['id']! as int,
      uuid: (draft.payload['expected']! as Map)['uuid']! as String,
      revision: (draft.payload['expected']! as Map)['revision']! as int,
    ),
    replacement: CoachFoodPortion.fromJson(draft.payload['replacement']),
  ),
};

BilActionReceipt _receiptFor(String actionId, CoachMealCommit result) =>
    BilActionReceipt(
      actionId: actionId,
      operationId: result.operationId,
      toolId: result.toolId,
      committed: true,
      completedAt: result.committedAt,
      entityType: result.after.length == 1 ? 'meal_item' : 'meal',
      entityId: result.after.length == 1
          ? result.after.single.item.id.toString()
          : result.after.first.meal.id.toString(),
      refreshTargets: const {
        'dailyMeals',
        'dailyLedger',
        'dashboard',
        'coachContext',
      },
      before: result.beforePayload,
      after: result.afterPayload,
      undoable: result.canUndo,
      undoneAt: result.undoneAt,
    );

final class _WidgetFixture {
  _WidgetFixture()
    : db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'bounded-food-owner',
      ) {
    foods = FoodRepository(db);
    meals = MealRepository(db);
    host = CoachFoodHost(
      foods: foods,
      meals: meals,
      preferences: PreferencesRepository(db),
    );
  }

  final AppDatabase db;
  late final FoodRepository foods;
  late final MealRepository meals;
  late final CoachFoodHost host;
  String get ownerKey => LocalDatabaseScope.keyForOwner(db.localOwnerId);

  CoachFoodOwnerScope foodScope() {
    final stamp = CoachFoodOwnerStamp(ownerKey: ownerKey, epoch: 0);
    return CoachFoodOwnerScope(captured: stamp, readCurrent: () => stamp);
  }

  Future<CoachFoodActionDraft> draft(
    String input,
    DateTime now, {
    int? preferredTargetItemId,
  }) async {
    final result = await host.prepare(
      input: input,
      referenceLocal: now,
      localeTag: 'ar',
      ownerScope: foodScope(),
      preferredTargetItemId: preferredTargetItemId,
    );
    expect(result, isA<CoachFoodActionDraft>());
    return result as CoachFoodActionDraft;
  }

  Future<int> seed(
    String name, {
    required double? calories,
    required double? protein,
    required double? carbs,
    required double? fat,
  }) async {
    final snapshot = CoachFoodSnapshot(
      identity: 'bounded:${normalizeFoodConcept(name)}',
      name: name,
      preparedState: 'as-recorded',
      basisGrams: 100,
      nutrients: CoachFoodNutrients({
        FoodNutrient.calories: calories,
        FoodNutrient.protein: protein,
        FoodNutrient.carbohydrates: carbs,
        FoodNutrient.fat: fat,
        FoodNutrient.fiber: null,
        FoodNutrient.sugar: null,
        FoodNutrient.sodium: null,
        FoodNutrient.potassium: null,
        FoodNutrient.calcium: null,
        FoodNutrient.magnesium: null,
        FoodNutrient.phosphorus: null,
        FoodNutrient.iron: null,
        FoodNutrient.vitaminC: null,
      }),
      source: CoachFoodSourceEvidence(
        kind: CoachFoodSourceKind.label,
        ref: 'bounded-label:$name',
        revision: 'v1',
      ),
    );
    final id = await foods.addFood(
      name: name,
      category: 'fixture',
      servingSize: 100,
      servingUnit: 'g',
      calories: calories ?? 0,
      protein: protein ?? 0,
      carbs: carbs ?? 0,
      fats: fat ?? 0,
      source: FoodBasisEvidence.sourceLabel(snapshot),
      verified: false,
      caloriesKnown: calories != null,
      proteinKnown: protein != null,
      carbsKnown: carbs != null,
      fatsKnown: fat != null,
    );
    await (db.update(db.foods)..where((row) => row.id.equals(id))).write(
      FoodsCompanion(
        category: const Value('coach_snapshot'),
        servingSize: const Value(100),
        servingUnit: const Value('g'),
        calories: Value(calories ?? 0),
        protein: Value(protein ?? 0),
        carbs: Value(carbs ?? 0),
        fats: Value(fat ?? 0),
        source: Value(FoodBasisEvidence.sourceLabel(snapshot)),
        verified: const Value(false),
        nutrientEvidenceMask: Value(FoodBasisEvidence.mask(snapshot)),
        foodEvidenceJson: Value(FoodBasisEvidence.encode(snapshot)),
      ),
    );
    return id;
  }

  Future<void> close() => db.close();
}
