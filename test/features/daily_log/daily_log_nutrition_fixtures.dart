import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../nutrition/food_basis_fixtures.dart';

MealItem modernDiaryItem({
  int id = 1,
  Map<FoodNutrient, double?> values = basisNutrients,
  CoachFoodSourceKind kind = CoachFoodSourceKind.label,
  String? ownerKey,
}) {
  final food = basisSnapshot(values: values, kind: kind, ownerKey: ownerKey);
  final portion = CoachFoodPortion(
    food: food,
    quantity: CoachFoodQuantity(
      grams: food.basisGrams,
      evidence: CoachFoodQuantityEvidence(
        kind: CoachFoodQuantityKind.userDeclared,
        description: 'The user supplied grams.',
      ),
    ),
  );
  double value(FoodNutrient nutrient) => portion.nutrients[nutrient] ?? 0;
  final now = DateTime(2026, 10, 6, 9);
  return MealItem(
    id: id,
    uuid: 'item-$id',
    mealId: 1,
    foodId: id,
    quantity: food.basisGrams,
    position: id,
    calories: value(FoodNutrient.calories),
    protein: value(FoodNutrient.protein),
    carbs: value(FoodNutrient.carbohydrates),
    fats: value(FoodNutrient.fat),
    fiber: value(FoodNutrient.fiber),
    sugar: value(FoodNutrient.sugar),
    sodium: value(FoodNutrient.sodium),
    potassium: value(FoodNutrient.potassium),
    calcium: value(FoodNutrient.calcium),
    magnesium: value(FoodNutrient.magnesium),
    phosphorus: value(FoodNutrient.phosphorus),
    nutrientEvidenceMask: FoodBasisEvidence.mask(food),
    foodSourceSnapshot: FoodBasisEvidence.sourceLabel(food),
    foodEvidenceJson: portion.encodeForStorage(),
    foodVerifiedSnapshot: false,
    servingSizeSnapshot: food.basisGrams,
    servingUnitSnapshot: 'g',
    createdAt: now,
    updatedAt: now,
    revision: 1,
    syncStatus: 'local',
  );
}

MealItem calorieOnlyDiaryItem() => modernDiaryItem(values: const {}).copyWith(
  quantity: 1,
  calories: 1905,
  nutrientEvidenceMask: NutrientEvidenceMask.bit(TrackedNutrient.calories),
  foodSourceSnapshot: 'quick_add',
  foodEvidenceJson: const Value(null),
  servingSizeSnapshot: 1,
  servingUnitSnapshot: 'entry',
);

MealWithItems diaryMeal(
  List<MealItem> items, {
  Map<int, Food> foods = const {},
  String? ownerKey,
}) {
  final now = DateTime(2026, 10, 6, 9);
  return MealWithItems(
    ownerKey: ownerKey,
    meal: Meal(
      id: 1,
      uuid: 'meal-1',
      date: now,
      dayKey: '2026-10-06',
      name: 'Breakfast',
      type: 'breakfast',
      createdAt: now,
      updatedAt: now,
      revision: 1,
      syncStatus: 'local',
    ),
    items: items,
    foodsById: foods,
  );
}

Future<void> pumpDiaryEvidence(
  WidgetTester tester,
  Widget child, {
  String language = 'en',
  Brightness brightness = Brightness.light,
  double scale = 1,
  double width = 390,
  ThemeData? theme,
  GlobalKey? repaintKey,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        verifiedSubscriptionAccessProvider.overrideWithValue(
          AsyncData(
            SubscriptionState(
              plan: CommercePlan.premium,
              entitlements: const {CommerceEntitlement.advancedIntelligence},
              authority: EntitlementAuthority.verifiedServer,
              isPurchasable: false,
              canRestorePurchases: false,
            ),
          ),
        ),
        diaryMealNamesProvider.overrideWithValue(
          const AsyncData([null, null, null, null]),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: theme ?? ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: repaintKey == null
              ? child!
              : RepaintBoundary(key: repaintKey, child: child),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

String diaryText(WidgetTester tester, String key) {
  final found = find.byKey(Key(key));
  final text = tester.widget<Text>(
    tester.widget(found) is Text
        ? found
        : find.descendant(of: found, matching: find.byType(Text)).first,
  );
  return text.data ?? text.textSpan!.toPlainText();
}
