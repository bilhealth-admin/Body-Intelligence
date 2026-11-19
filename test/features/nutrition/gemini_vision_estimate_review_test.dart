import 'dart:async';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/gemini_vision_estimate.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/gemini_vision_estimate_review.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_premium_review.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_gateway_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

MealImageAnalysis analysis({bool empty = false}) {
  final e = GeminiVisionEstimate(
    requestId: 'review-photo',
    index: 0,
    name: 'Visible meal',
    modelRevision: 'gemini-test',
    promptRevision: 'photo-test',
    basis: empty ? null : GeminiEstimateBasis(quantity: 100, unit: 'g'),
    picturedAmount: empty ? null : 150,
    picturedUnit: empty ? null : 'g',
    nutrients: GeminiEstimateNutrients(
      empty
          ? {}
          : {
              for (final n in FoodNutrient.values)
                n: switch (n) {
                  FoodNutrient.calories => 160,
                  FoodNutrient.carbohydrates => 20,
                  FoodNutrient.fiber => 3,
                  FoodNutrient.sugar => 0,
                  _ => 1,
                },
            },
      netCarbohydrates: empty ? null : 17,
    ),
  );
  return MealImageAnalysis(
    schemaVersion: 2,
    requestId: e.requestId,
    notice: 'Estimate',
    estimates: [e],
    candidates: [
      MealImageCandidate(
        name: e.name,
        confidence: .8,
        evidence: 'Visible portion',
        identificationProvider: 'gemini',
        modelRevision: e.modelRevision,
        nutritionResolution: MealNutritionResolution.geminiPhotoEstimate,
        amount: e.picturedAmount,
        unit: e.picturedUnit,
      ),
    ],
  );
}

Finder k(String key, {bool offstage = false}) =>
    find.byKey(Key(key), skipOffstage: !offstage);
Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> open(
  WidgetTester t, {
  MealImageAnalysis? value,
  bool saves = false,
  Locale locale = const Locale('en'),
  double scale = 1,
  bool Function()? current,
  MealVisionReviewLifetime? lifetime,
  Future<MealVisionReviewDecision> Function(List<ReviewedGeminiVisionEstimate>)?
  confirm,
  void Function(List<ReviewedGeminiVisionEstimate>?)? result,
}) async {
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              unawaited(
                showGeminiVisionEstimateReview(
                  context,
                  analysis: value ?? analysis(),
                  isCurrent: current ?? () => true,
                  lifetime: lifetime ?? MealVisionReviewLifetime(),
                  savesToDiary: saves,
                  onConfirm: confirm,
                ).then((value) => result?.call(value)),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.text('Open'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'first Review shows Gemini seven nutrients and portion without forced Stage or Eaten',
    (t) async {
      var confirmed = 0;
      await open(
        t,
        confirm: (_) async {
          confirmed++;
          return const MealVisionReviewDecision.accepted();
        },
      );
      expect(t.widget<Text>(k('gemini-value-0-calories')).data, '240.0 kcal');
      expect(t.widget<Text>(k('gemini-value-0-protein')).data, '1.5 g');
      expect(t.widget<Text>(k('gemini-value-0-carbohydrates')).data, '30.0 g');
      expect(t.widget<Text>(k('gemini-value-0-fat')).data, '1.5 g');
      expect(t.widget<Text>(k('gemini-value-0-fiber')).data, '4.5 g');
      expect(
        t.widget<Text>(k('gemini-value-0-netCarbohydrates')).data,
        '25.5 g',
      );
      expect(t.widget<Text>(k('gemini-value-0-sugar')).data, '0.0 g');
      expect(find.textContaining('Google Gemini'), findsOneWidget);
      expect(find.textContaining('150.0 g'), findsOneWidget);
      expect(
        find.byKey(const Key('premium-vision-stage-before')),
        findsNothing,
      );
      expect(find.byKey(const Key('premium-vision-eaten-0')), findsNothing);
      expect(confirmed, 0);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'single Use confirms valid Gemini pictured portion with no extra required manual fields',
    (t) async {
      List<ReviewedGeminiVisionEstimate>? selected;
      await open(t, result: (v) => selected = v);
      expect(find.text('Use this estimate'), findsOneWidget);
      await tap(t, k('gemini-estimate-confirm'));
      expect(selected, hasLength(1));
      expect(selected!.single.amount, 150);
      expect(selected!.single.unit, 'g');
      expect(k('gemini-required-details'), findsNothing);
    },
  );
  testWidgets(
    'explicit diary Save is the only atomic write and double tap cannot duplicate it',
    (t) async {
      const owner = '11111111-1111-4111-8111-111111111111';
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      final held = Completer<void>();
      var calls = 0;
      try {
        await open(
          t,
          saves: true,
          confirm: (items) async {
            calls++;
            await held.future;
            await MealRepository(db).addGeminiVisionMealAtomically(
              date: DateTime(2026, 11, 18),
              mealType: 'lunch',
              ownerId: owner,
              requestId: 'review-photo',
              items: items,
              isCurrentOwner: () => true,
            );
            return const MealVisionReviewDecision.accepted();
          },
        );
        expect(await db.select(db.mealItems).get(), isEmpty);
        expect(find.text('Save'), findsOneWidget);
        await t.ensureVisible(k('gemini-estimate-confirm'));
        await t.tap(k('gemini-estimate-confirm'));
        await t.pump();
        await t.tap(k('gemini-estimate-confirm'));
        await t.pump();
        expect(calls, 1);
        held.complete();
        await t.pumpAndSettle();
        final row = (await db.select(db.mealItems).get()).single;
        expect(
          MealFoodEvidence.read(row).fullValue(FoodNutrient.calories),
          240,
        );
        expect(
          MealFoodEvidence.read(row).fullValue(FoodNutrient.vitaminA),
          1.5,
        );
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await db.close();
      }
    },
  );
  testWidgets(
    'optional amount editing changes preview once and preserves Gemini basis',
    (t) async {
      List<ReviewedGeminiVisionEstimate>? selected;
      await open(t, result: (v) => selected = v);
      await tap(t, k('gemini-edit-portion-0'));
      await t.enterText(k('gemini-amount-0'), '50');
      await t.pumpAndSettle();
      expect(t.widget<Text>(k('gemini-value-0-calories')).data, '80.0 kcal');
      await tap(t, k('gemini-estimate-confirm'));
      expect(selected!.single.amount, 50);
      expect(selected!.single.estimate.basis!.quantity, 100);
      expect(selected!.single.estimate.nutrients[FoodNutrient.calories], 160);
    },
  );
  testWidgets(
    'missing amount opens Pearl and expands then focuses that exact optional editor',
    (t) async {
      var confirms = 0;
      await open(
        t,
        confirm: (_) async {
          confirms++;
          return const MealVisionReviewDecision.accepted();
        },
      );
      await tap(t, k('gemini-edit-portion-0'));
      await t.enterText(k('gemini-amount-0'), '');
      t.testTextInput.hide();
      await tap(t, k('gemini-edit-portion-0'));
      await tap(t, k('gemini-estimate-confirm'));
      expect(k('gemini-required-details'), findsOneWidget);
      expect(confirms, 0);
      await tap(t, k('gemini-missing-amount-0'));
      final field = t.widget<TextField>(k('gemini-amount-0'));
      expect(field.focusNode!.hasFocus, isTrue);
      expect(field.controller!.text, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'unknown nutrition stays unavailable and cannot save random zeros',
    (t) async {
      var confirms = 0;
      await open(
        t,
        value: analysis(empty: true),
        confirm: (_) async {
          confirms++;
          return const MealVisionReviewDecision.accepted();
        },
      );
      expect(t.widget<Text>(k('gemini-value-0-calories')).data, '—');
      await tap(t, k('gemini-estimate-confirm'));
      expect(k('gemini-missing-source-0'), findsOneWidget);
      expect(k('gemini-missing-amount-0'), findsOneWidget);
      expect(confirms, 0);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Cancel writes nothing and returns no estimate', (t) async {
    var confirms = 0;
    var returned = false;
    List<ReviewedGeminiVisionEstimate>? result;
    await open(
      t,
      confirm: (_) async {
        confirms++;
        return const MealVisionReviewDecision.accepted();
      },
      result: (v) {
        returned = true;
        result = v;
      },
    );
    await tap(t, k('gemini-review-close'));
    expect(returned, isTrue);
    expect(result, isNull);
    expect(confirms, 0);
  });
  testWidgets(
    'retired owner while confirmation is held cannot accept its late result',
    (t) async {
      var current = true;
      final lifetime = MealVisionReviewLifetime();
      final held = Completer<MealVisionReviewDecision>();
      List<ReviewedGeminiVisionEstimate>? result;
      await open(
        t,
        current: () => current,
        lifetime: lifetime,
        confirm: (_) => held.future,
        result: (v) => result = v,
      );
      await t.ensureVisible(k('gemini-estimate-confirm'));
      await t.tap(k('gemini-estimate-confirm'));
      await t.pump();
      current = false;
      lifetime.retire();
      await t.pump();
      await t.pump();
      held.complete(const MealVisionReviewDecision.accepted());
      await t.pumpAndSettle();
      expect(result, isNull);
      expect(k('gemini-estimate-confirm'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'micros are expandable and show provided electrolytes without extra lookup',
    (t) async {
      await open(t);
      await tap(t, k('gemini-more-nutrients-0'));
      for (final n in [
        FoodNutrient.sodium,
        FoodNutrient.potassium,
        FoodNutrient.magnesium,
        FoodNutrient.cholesterol,
        FoodNutrient.vitaminA,
      ]) {
        expect(
          t.widget<Text>(k('gemini-value-0-${n.name}')).data,
          startsWith('1.5 '),
        );
      }
    },
  );
  testWidgets(
    'Arabic320x700 at2x keeps whole review and Pearl validation scrollable',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await open(t, locale: const Locale('ar'), scale: 2);
      expect(find.text('اعتمد هذا التقدير'), findsOneWidget);
      await tap(t, k('gemini-selection-0'));
      await tap(t, k('gemini-estimate-confirm'));
      expect(k('gemini-required-details'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(find.text('اختر مكوّنًا واحدًا على الأقل'), findsOneWidget);
      await tap(t, k('gemini-missing-selection-0'));
      expect(
        t.widget<Checkbox>(k('gemini-selection-0')).focusNode!.hasFocus,
        isTrue,
      );
      expect(t.takeException(), isNull);
    },
  );
}
