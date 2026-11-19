import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_premium_review.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_gateway_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';
import 'vision_v2_test_fixture.dart';

Future<void> _tapReviewControl(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final width in <double>[320, 390, 430]) {
    testWidgets('Vision immersive RTL shell $width keeps safe review controls', (
      tester,
    ) async {
      await setVisionV2Viewport(tester, Size(width, 844));
      final lifetime = MealVisionReviewLifetime();
      List<PremiumVisionSelection>? result;
      var returned = false;
      var confirmations = 0;
      try {
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
                  onPressed: () async {
                    result = await showPremiumVisionReviewDialog(
                      context,
                      analysis: analysis,
                      mealType: 'breakfast',
                      photographedAt: DateTime(2026, 10, 10, 11, 30),
                      lifetime: lifetime,
                      onConfirm: (_) async {
                        confirmations++;
                        return const MealVisionReviewDecision.accepted();
                      },
                    );
                    returned = true;
                  },
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
        // Enabled means required-field guidance is available, not confirmed.
        expect(continueButton.onPressed, isNotNull);
        final continueControl = find.byKey(
          const Key('premium-vision-continue'),
        );
        await _tapReviewControl(tester, continueControl);
        expect(
          find.byKey(const Key('vision-required-details')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('vision-missing-stage')), findsOneWidget);
        expect(
          find.byKey(const Key('vision-missing-selection-0')),
          findsOneWidget,
        );
        expect(confirmations, 0);
        expect(returned, isFalse);
        expect(result, isNull);
        await _tapReviewControl(
          tester,
          find.byKey(const Key('vision-required-cancel')),
        );
        expect(
          tester
              .widget<Checkbox>(
                find.byKey(const Key('premium-vision-select-0')),
              )
              .value,
          isFalse,
        );
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const Key('premium-vision-stage-before')),
              )
              .selected,
          isFalse,
        );
        // Recovery focuses the missing input; it cannot answer it for the user.
        await _tapReviewControl(tester, continueControl);
        await _tapReviewControl(
          tester,
          find.byKey(const Key('vision-missing-selection-0')),
        );
        expect(find.byKey(const Key('vision-required-details')), findsNothing);
        expect(
          tester
              .widget<Checkbox>(
                find.byKey(const Key('premium-vision-select-0')),
              )
              .focusNode!
              .hasFocus,
          isTrue,
        );
        expect(
          tester
              .widget<Checkbox>(
                find.byKey(const Key('premium-vision-select-0')),
              )
              .value,
          isFalse,
        );
        expect(confirmations, 0);
        expect(returned, isFalse);
        final staleContinue = tester
            .widget<FilledButton>(continueControl)
            .onPressed!;
        lifetime.retire();
        staleContinue();
        await tester.pumpAndSettle();
        expect(returned, isTrue);
        expect(result, isNull);
        expect(confirmations, 0);
        expect(
          find.byKey(const Key('premium-vision-render-surface')),
          findsNothing,
        );
        expect(find.byKey(const Key('vision-required-details')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        lifetime.retire();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });
  }
}
