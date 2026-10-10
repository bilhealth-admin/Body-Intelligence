import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_premium_review.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_gateway_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';
import 'vision_v2_test_fixture.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final width in <double>[320, 390, 430]) {
    testWidgets(
      'Vision immersive RTL shell $width keeps safe review controls',
      (tester) async {
        await setVisionV2Viewport(tester, Size(width, 844));
        final analysis = MealImageAnalysis(
          requestId: 'vision-layout-fixture',
          notice: 'Fixture, no nutrient source',
          candidates: [
            const MealImageCandidate(
              name: 'فول مدمس مع طحينة',
              confidence: 0.88,
              evidence: 'عينة اختبار',
              identificationProvider: 'test-fixture',
              modelRevision: 'fixture',
              nutritionResolution:
                  MealNutritionResolution.requiresVerifiedFoodMatch,
              amount: 60,
              unit: 'g',
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: visualEvidenceTheme(
              ThemeData(useMaterial3: true),
              fontFamily: 'NotoArabicEvidence',
            ),
            builder: (context, child) => visualEvidenceTextSurface(
              child,
              fontFamily: 'NotoArabicEvidence',
            ),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showPremiumVisionReviewDialog(
                    context,
                    analysis: analysis,
                    mealType: 'breakfast',
                    photographedAt: DateTime(2026, 10, 10, 11, 30),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('BIL Vision'), findsOneWidget);
        expect(
          find.byKey(const Key('premium-vision-render-surface')),
          findsOneWidget,
        );
        final shell = tester.getSize(
          find.byKey(const Key('premium-vision-render-surface')),
        );
        expect(shell.width, closeTo(width, 1));
        expect(shell.height, closeTo(844, 1));
        final clock = find.byKey(const Key('premium-vision-clock'));
        expect(tester.widget<Text>(clock).data, '11:30');
        final clockDirection = find.ancestor(
          of: clock,
          matching: find.byType(Directionality),
        );
        expect(
          tester.widget<Directionality>(clockDirection.first).textDirection,
          TextDirection.ltr,
        );
        expect(
          find.byKey(const Key('premium-vision-unverified-nutrition')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('premium-vision-photo')), findsNothing);
        expect(find.textContaining('الصورة غير متاحة'), findsOneWidget);
        final continueButton = tester.widget<FilledButton>(
          find.byKey(const Key('premium-vision-continue')),
        );
        expect(continueButton.onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
