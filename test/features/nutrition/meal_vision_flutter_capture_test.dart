import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_premium_review.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_gateway_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel evidence from Flutter's widget renderer on a test surface.
/// This does NOT claim to be a physical iPhone or Android screenshot.
/// No photo is substituted for a user's real image.
Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('premium-vision-render-surface')),
  );
  final image = await boundary.toImage(pixelRatio: 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(data, isNotNull);
  final path = File('build/vision-captures/$name.png');
  await path.parent.create(recursive: true);
  await path.writeAsBytes(data!.buffer.asUint8List());
  expect(await path.length(), greaterThan(2500));
  image.dispose();
}

MaterialApp _app(Widget child) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
  home: Scaffold(body: child),
);

MealImageAnalysis _analysis() => const MealImageAnalysis(
  requestId: 'flutter-render-fixture',
  notice: 'Fixture — no meal was saved',
  candidates: [
    MealImageCandidate(
      name: 'فول مدمس مع طحينة',
      confidence: 0.88,
      evidence: 'رُصد الطعام بصريًا (عينة اختبار)',
      identificationProvider: 'flutter-test-fixture',
      modelRevision: 'fixture',
      nutritionResolution: MealNutritionResolution.requiresVerifiedFoodMatch,
      amount: 60,
      unit: 'g',
      uncertainty: 'هل الكمية مأكولة أم متبقية؟',
      alternatives: [
        MealImageAlternative(name: 'فول سادة', confidence: 0.63),
      ],
    ),
  ],
);

Food _verifiedFixture() {
  final now = DateTime(2026, 10, 10);
  return Food(
    id: 1,
    uuid: 'vision-render-fixture-food',
    name: 'Verified ful (fixture)',
    arabicName: 'فول مدمس — عينة اختبار موثوقة',
    category: 'Test',
    keywords: 'ful',
    servingSize: 100,
    servingUnit: 'g',
    calories: 95,
    protein: 5.1,
    carbs: 11.9,
    fats: 3.4,
    fiber: 3.5,
    sugar: 0,
    sodium: 0,
    potassium: 170,
    calcium: 45,
    magnesium: 29,
    phosphorus: 111,
    iron: 0,
    vitaminC: 0,
    nutrientEvidenceMask: NutrientEvidenceMask.fromValues(
      calories: 95, protein: 5.1, carbohydrates: 11.9, fat: 3.4,
      fiber: 3.5, potassium: 170, calcium: 45, magnesium: 29,
      phosphorus: 111,
    ),
    source: 'foundation-test-fixture',
    verified: true,
    isCustom: false,
    createdAt: now,
    updatedAt: now,
    revision: 1,
    syncStatus: 'local',
  );
}

void main() {
  testWidgets('capture actual Flutter-rendered BIL Vision review panels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(Builder(builder: (context) =>
      Center(child: FilledButton(
        onPressed: () => showPremiumVisionReviewDialog(
          context,
          analysis: _analysis(),
          mealType: 'breakfast',
          photographedAt: DateTime(2026, 10, 10, 11, 30),
        ),
        child: const Text('فتح'),
      )),
    )));
    await tester.tap(find.text('فتح'));
    await _capture(tester, '01_review_ar_dark');
    await tester.ensureVisible(find.byKey(const Key('premium-vision-stage-during')));
    await tester.tap(find.byKey(const Key('premium-vision-stage-during')));
    await tester.ensureVisible(find.byKey(const Key('premium-vision-select-0')));
    await tester.tap(find.byKey(const Key('premium-vision-select-0')));
    await tester.ensureVisible(find.byKey(const Key('premium-vision-eaten-0')));
    await tester.tap(find.byKey(const Key('premium-vision-eaten-0')));
    await _capture(tester, '02_review_eaten_confirmation_ar_dark');
  });

  testWidgets('capture trusted-source quick and full nutrition Flutter panels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(Builder(builder: (context) =>
      Center(child: FilledButton(
        onPressed: () => showPremiumTrustedVisionFoodMatchDialog(
          context,
          recognizedName: 'فول مدمس — عينة اختبار',
          foods: [_verifiedFixture()],
          reviewedAmount: 80,
          reviewedUnit: 'g',
        ),
        child: const Text('فتح المطابقة'),
      )),
    )));
    await tester.tap(find.text('فتح المطابقة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verified ful (fixture)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('premium-vision-trusted-nutrients')));
    await _capture(tester, '03_nutrition_quick_ar_dark');
    await tester.ensureVisible(find.byKey(const Key('premium-vision-full-toggle')));
    await tester.tap(find.byKey(const Key('premium-vision-full-toggle')));
    await _capture(tester, '04_nutrition_full_ar_dark');
  });
}
