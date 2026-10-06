import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/bil_action_receipt.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../visual_closure/visual_evidence_font.dart';

/// Synthetic, explicitly attributed QA food bases. The 407/36/18/20 display
/// vectors exercise reference geometry; they are not nutrition claims about
/// eggs, milk or any real brand, and never leave this isolated Drift database.
final class CoachFoodCardsFixture {
  CoachFoodCardsFixture._(this.database)
    : repository = MealRepository(database),
      review = foodCardFixtureReview();

  static const owner = 'coach-food-card-owner';
  static final day = DateTime(2026, 10, 6);
  final AppDatabase database;
  final MealRepository repository;
  final CoachFoodReview review;
  bool ownerCurrent = true;
  final List<CoachMealOwnerScope> _scopes = [];

  static Future<CoachFoodCardsFixture> create() async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: owner,
    );
    await db.customSelect('SELECT 1').get();
    return CoachFoodCardsFixture._(db);
  }

  CoachMealOwnerScope scope() {
    final value = CoachMealOwnerScope(
      ownerId: owner,
      isCurrent: () => ownerCurrent,
    );
    _scopes.add(value);
    return value;
  }

  void cancelOwner() {
    ownerCurrent = false;
    for (final value in _scopes) {
      value.cancel();
    }
  }

  Future<CoachMealCommit> commitReview({
    String operationId = 'food-card-breakfast',
    CoachFoodReview? proposal,
  }) => repository.commitCoachMeal(
    command: CoachMealCommand.foods(
      operationId: operationId,
      date: day,
      mealType: 'breakfast',
      review: proposal ?? review,
    ),
    scope: scope(),
  );

  Future<CoachMealCommit> commitCalories({
    String operationId = 'food-card-calories',
  }) => repository.commitCoachMeal(
    command: CoachMealCommand.quickMacros(
      operationId: operationId,
      date: day,
      mealType: 'snack',
      calories: 1905,
    ),
    scope: scope(),
  );

  Future<CoachMealCommit> undo(CoachMealCommit commit) =>
      repository.undoCoachMeal(
        operationId: commit.operationId,
        toolId: commit.toolId,
        argumentsDigest: commit.argumentsDigest,
        scope: scope(),
      );

  Future<void> close() => database.close();
}

CoachFoodReview foodCardFixtureReview({bool unknownProtein = false}) {
  final data = <(String, double, double, double, double, double, double)>[
    ('Boiled eggs', 150, 210, 18, 1, 14, 140),
    ('Juhayna skim milk', 200, 110, 10, 9, 2, 90),
    ('Tomato', 123, 32, 3, 4, 1, 8),
    ('Cucumber', 200, 55, 5, 4, 3, 4),
  ];
  final items = <CoachFoodPortion>[];
  for (var index = 0; index < data.length; index++) {
    final (name, grams, calories, protein, carbs, fat, sodium) = data[index];
    final estimated = index > 1;
    final source = CoachFoodSourceEvidence(
      kind: index == 1
          ? CoachFoodSourceKind.label
          : CoachFoodSourceKind.reference,
      ref: 'qa:isolated-drift:food-$index',
      revision: 'qa-only-1',
      confidence: CoachFoodConfidence(score: .91, basis: 'QA source evidence'),
    );
    final conversionSource = estimated
        ? CoachFoodSourceEvidence(
            kind: CoachFoodSourceKind.estimated,
            ref: 'qa:isolated-drift:portion-$index',
            revision: 'qa-only-1',
          )
        : source;
    final count = switch (index) {
      0 => 3.0,
      1 => 200.0,
      2 => 1.0,
      _ => 2.0,
    };
    items.add(
      CoachFoodPortion(
        food: CoachFoodSnapshot(
          identity: 'qa-food-$index',
          name: name,
          preparedState: 'QA fixture',
          basisGrams: grams,
          nutrients: CoachFoodNutrients({
            for (final nutrient in FoodNutrient.values) nutrient: 0,
            FoodNutrient.calories: calories,
            FoodNutrient.protein: unknownProtein && index == 2 ? null : protein,
            FoodNutrient.carbohydrates: carbs,
            FoodNutrient.fat: fat,
            FoodNutrient.sodium: sodium,
          }),
          source: source,
        ),
        quantity: CoachFoodQuantity(
          grams: grams,
          evidence: CoachFoodQuantityEvidence(
            kind: estimated
                ? CoachFoodQuantityKind.estimated
                : CoachFoodQuantityKind.userDeclared,
            description: estimated
                ? 'QA estimated portion'
                : 'QA declared amount',
            confidence: CoachFoodConfidence(
              score: .63,
              basis: 'QA quantity evidence',
            ),
            conversion: CoachFoodQuantityConversion(
              inputAmount: count,
              inputUnit: index == 1 ? 'ml' : 'item',
              gramsPerUnit: grams / count,
              source: conversionSource,
            ),
          ),
        ),
        identityConfidence: CoachFoodConfidence(
          score: .98,
          basis: 'QA matched identity',
        ),
      ),
    );
  }
  return CoachFoodReview(items);
}

BilActionReceipt foodCardReceipt(
  CoachMealCommit commit, {
  bool committed = true,
  String? operationId,
  String? toolId,
  DateTime? completedAt,
  String? entityType,
  String? entityId,
  Map<String, Object?>? after,
  bool? undoable,
}) {
  final single = commit.after.length == 1;
  return BilActionReceipt(
    actionId: 'qa-renderer-action',
    operationId: operationId ?? commit.operationId,
    toolId: toolId ?? commit.toolId,
    committed: committed,
    completedAt: completedAt ?? commit.committedAt,
    entityType: entityType ?? (single ? 'meal_item' : 'meal'),
    entityId:
        entityId ??
        (single ? commit.after.single.item.id : commit.after.first.meal.id)
            .toString(),
    before: commit.beforePayload,
    after:
        after ??
        (commit.state == CoachMealResultState.undone
            ? {
                'state': commit.state.name,
                'items': commit.current
                    .map((item) => item?.toReceiptPayload())
                    .toList(),
                'arguments_digest': commit.argumentsDigest,
              }
            : commit.afterPayload),
    undoable: undoable ?? commit.canUndo,
    undoneAt: commit.undoneAt,
  );
}

Future<void> mountFoodCard(
  WidgetTester tester,
  Widget child, {
  String language = 'en',
  double scale = 1,
  double width = 390,
  double height = 844,
  bool evidenceFont = false,
  GlobalKey? captureKey,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  final theme = BilFlagshipTheme.dark(isArabic: language == 'ar');
  final surface = Scaffold(
    backgroundColor: const Color(0xFF070F19),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QA fixture · isolated Drift',
            style: TextStyle(color: Color(0xFFAFBBCB), fontSize: 10),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: evidenceFont
          ? visualEvidenceTheme(
              theme,
              fontFamily: language == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence',
            )
          : theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: evidenceFont ? visualEvidenceTextSurface(child!) : child!,
      ),
      home: captureKey == null
          ? surface
          : RepaintBoundary(key: captureKey, child: surface),
    ),
  );
  await tester.pumpAndSettle();
}
