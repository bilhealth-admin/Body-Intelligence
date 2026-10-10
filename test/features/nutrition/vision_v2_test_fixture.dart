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

import '../../visual_closure/visual_evidence_font.dart';

const visionV2MealAsset =
    'assets/images/professional/recipes/ful-medames-tahini.png';
const visionV2PhotoPath = 'build/vision-v2-captures/TEST_FIXTURE_MEAL_ful.png';

Future<void> prepareVisionV2Fixture() async {
  await loadVisualEvidenceFont();
  await Directory('build/vision-v2-captures').create(recursive: true);
  // Deliberately supplied TEST input, byte-for-byte copy of repository art.
  // Never a substitute when the product receives no imagePath.
  await File(visionV2MealAsset).copy(visionV2PhotoPath);
}

MaterialApp visionV2App(
  Widget home, {
  String language = 'ar',
  Brightness brightness = Brightness.dark,
  double scale = 1,
}) {
  final family = language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence';
  return MaterialApp(
    locale: Locale(language),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: visualEvidenceTheme(
      ThemeData(useMaterial3: true, brightness: brightness),
      fontFamily: family,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(
        key: const Key('v2-test-screen'),
        child: visualEvidenceTextSurface(child, fontFamily: family),
      ),
    ),
    home: Scaffold(body: home),
  );
}

Future<void> setVisionV2Viewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
    tester.view.resetPadding();
    await tester.binding.setSurfaceSize(null);
  });
}

MealImageAnalysis visionV2Analysis({
  String language = 'ar',
}) => MealImageAnalysis(
  requestId: 'v2-TEST-fixture-only',
  notice: 'TEST FIXTURE — no camera, AI request or meal write',
  candidates: [
    MealImageCandidate(
      name: language == 'ar' ? 'فول مدمس — عينة اختبار' : 'Ful — TEST FIXTURE',
      confidence: .88,
      evidence: language == 'ar'
          ? 'عينة اختبار فقط — ليست صورة مستخدم أو تحليلًا حقيقيًا'
          : 'TEST FIXTURE ONLY — not a user photo or real AI analysis',
      identificationProvider: 'test-fixture',
      modelRevision: 'fixture',
      nutritionResolution: MealNutritionResolution.requiresVerifiedFoodMatch,
      amount: 60,
      unit: 'g',
      verifiedFoodRecordId: 'v2-test-food',
      alternatives: const [
        MealImageAlternative(name: 'Alternative TEST food', confidence: .63),
      ],
    ),
  ],
);

Food visionV2Food({String unit = 'g', double serving = 100}) {
  final date = DateTime(2026, 10, 10);
  return Food(
    id: 7,
    uuid: 'v2-test-food',
    name: 'Verified ful — TEST FIXTURE',
    arabicName: 'فول موثوق — عينة اختبار',
    category: 'Test',
    keywords: 'ful',
    servingSize: serving,
    servingUnit: unit,
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
      calories: 95,
      protein: 5.1,
      carbohydrates: 11.9,
      fat: 3.4,
      fiber: 3.5,
      potassium: 170,
      calcium: 45,
      magnesium: 29,
      phosphorus: 111,
    ),
    source: 'TEST-FIXTURE-not-production',
    verified: true,
    isCustom: false,
    createdAt: date,
    updatedAt: date,
    revision: 1,
    syncStatus: 'local',
  );
}

Future<void> openVisionV2Review(
  WidgetTester tester, {
  String language = 'ar',
  Brightness brightness = Brightness.dark,
  double scale = 1,
  bool photo = true,
  void Function(List<PremiumVisionSelection>?)? onResult,
}) async {
  await tester.pumpWidget(
    visionV2App(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showPremiumVisionReviewDialog(
            context,
            analysis: visionV2Analysis(language: language),
            imagePath: photo ? visionV2PhotoPath : null,
            mealType: 'breakfast',
            photographedAt: DateTime(2026, 10, 10, 11, 30),
          ).then((value) => onResult?.call(value)),
          child: const Text('OPEN TEST REVIEW'),
        ),
      ),
      language: language,
      brightness: brightness,
      scale: scale,
    ),
  );
  await tester.tap(find.text('OPEN TEST REVIEW'));
  await tester.pumpAndSettle();
  if (photo) {
    for (var i = 0; i < 100; i++) {
      final images = tester.widgetList<RawImage>(
        find.descendant(
          of: find.byKey(const Key('premium-vision-photo')),
          matching: find.byType(RawImage),
        ),
      );
      if (images.any((image) => image.image != null)) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    fail('Original TEST input photo did not decode.');
  }
}

Future<void> captureVisionV2(
  WidgetTester tester,
  String name, {
  bool wholeScreen = false,
}) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(
      Key(wholeScreen ? 'v2-test-screen' : 'premium-vision-render-surface'),
    ),
  );
  // An engine snapshot may preserve retained compositing layers even after
  // the widget text is updated. Mark the complete test surface for painting
  // before capturing evidence so the PNG reflects the latest portion value.
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  repaint(boundary);
  await tester.pump();
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      await File(
        'build/vision-v2-captures/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
