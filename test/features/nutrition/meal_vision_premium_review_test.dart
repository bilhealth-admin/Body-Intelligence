import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_premium_review.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_gateway_contract.dart';

import 'food_basis_fixtures.dart';

void main() {
  MealImageAnalysis sample({bool leftovers = false}) => MealImageAnalysis(
    requestId: 'review-test',
    notice: 'Review every food before saving',
    candidates: [
      MealImageCandidate(
        name: 'فول مدمس مع طحينة',
        confidence: leftovers ? 0.42 : 0.88,
        evidence: 'رُصد الطعام في الصورة',
        identificationProvider: 'test',
        modelRevision: '1',
        nutritionResolution: MealNutritionResolution.requiresVerifiedFoodMatch,
        amount: 60,
        unit: 'g',
        uncertainty: leftovers ? 'قد يكون الطبق مأكولًا جزئيًا' : null,
        alternatives: const [
          MealImageAlternative(name: 'فول سادة', confidence: .66),
        ],
      ),
    ],
  );

  Future<void> open(
    WidgetTester tester,
    MealImageAnalysis analysis,
    void Function(List<PremiumVisionSelection>?) onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
              ).then(onResult),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('No selected food or inferred portion is auto-logged', (
    tester,
  ) async {
    List<PremiumVisionSelection>? result;
    await open(tester, sample(), (v) => result = v);
    expect(find.text('BIL Vision'), findsOneWidget);
    expect(find.byKey(const Key('premium-vision-continue')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('premium-vision-continue')),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-select-0')),
    );
    await tester.tap(find.byKey(const Key('premium-vision-select-0')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('premium-vision-continue')),
          )
          .onPressed,
      isNull,
    );
    expect(result, isNull);
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-stage-before')),
    );
    await tester.tap(find.byKey(const Key('premium-vision-stage-before')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('premium-vision-eaten-0')));
    await tester.tap(find.byKey(const Key('premium-vision-eaten-0')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-continue')),
    );
    await tester.tap(find.byKey(const Key('premium-vision-continue')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.single.amount, 60);
    expect(result!.single.unit, 'g');
  });

  testWidgets('Leftovers are never mistaken for amount consumed', (
    tester,
  ) async {
    List<PremiumVisionSelection>? result;
    await open(tester, sample(leftovers: true), (v) => result = v);
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-stage-after')),
    );
    await tester.tap(find.byKey(const Key('premium-vision-stage-after')));
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-select-0')),
    );
    await tester.tap(find.byKey(const Key('premium-vision-select-0')));
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-remaining-0')),
    );
    await tester.tap(find.byKey(const Key('premium-vision-remaining-0')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('premium-vision-amount-0')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('premium-vision-continue')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('premium-vision-eaten-0')));
    await tester.enterText(
      find.byKey(const Key('premium-vision-amount-0')),
      '80',
    );
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-continue')),
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('premium-vision-continue')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('premium-vision-continue')));
    await tester.pumpAndSettle();
    expect(result!.single.amount, 80);
  });

  testWidgets('Rejects zero portion with visible validation', (tester) async {
    await open(tester, sample(), (_) {});
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-stage-during')),
    );
    await tester.tap(find.byKey(const Key('premium-vision-stage-during')));
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-select-0')),
    );
    await tester.tap(find.byKey(const Key('premium-vision-select-0')));
    await tester.ensureVisible(find.byKey(const Key('premium-vision-eaten-0')));
    await tester.tap(find.byKey(const Key('premium-vision-eaten-0')));
    await tester.enterText(
      find.byKey(const Key('premium-vision-amount-0')),
      '0',
    );
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-continue')),
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('premium-vision-continue')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Alternative changes identity without retaining verified record',
    (tester) async {
      List<PremiumVisionSelection>? result;
      await open(tester, sample(), (v) => result = v);
      await tester.ensureVisible(
        find.byKey(const Key('premium-vision-stage-before')),
      );
      await tester.tap(find.byKey(const Key('premium-vision-stage-before')));
      await tester.ensureVisible(
        find.byKey(const Key('premium-vision-select-0')),
      );
      await tester.tap(find.byKey(const Key('premium-vision-select-0')));
      await tester.ensureVisible(find.text('فول سادة'));
      await tester.tap(find.text('فول سادة'));
      await tester.ensureVisible(
        find.byKey(const Key('premium-vision-eaten-0')),
      );
      await tester.tap(find.byKey(const Key('premium-vision-eaten-0')));
      await tester.ensureVisible(
        find.byKey(const Key('premium-vision-continue')),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('premium-vision-continue')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('premium-vision-continue')));
      await tester.pumpAndSettle();
      expect(result!.single.candidate.name, 'فول سادة');
      expect(result!.single.candidate.verifiedFoodRecordId, isNull);
    },
  );

  testWidgets('Only image from user may appear; no substitute meal photo', (
    tester,
  ) async {
    await open(tester, sample(), (_) {});
    expect(find.textContaining('الصورة غير متاحة'), findsOneWidget);
    expect(find.byKey(const Key('premium-vision-photo')), findsNothing);
  });
  test('modern label source needs matching owner proof, not just a food name', () {
    final record = basisFood(snapshot: basisSnapshot(ownerKey: 'source-owner'));
    expect(record.verified, isFalse);
    expect(mealVisionFoodCanBeUsed(record), isFalse);
    expect(
      mealVisionFoodCanBeUsed(record, evidenceOwnerKey: 'other-owner'),
      isFalse,
    );
    expect(
      mealVisionFoodCanBeUsed(record, evidenceOwnerKey: 'source-owner'),
      isTrue,
    );
    final corrupt = basisFood(
      snapshot: basisSnapshot(ownerKey: 'source-owner'),
      raw: '{"schema":"unsupported"}',
    );
    expect(
      mealVisionFoodCanBeUsed(corrupt, evidenceOwnerKey: 'source-owner'),
      isFalse,
    );
  });

  testWidgets('owner-bound label may be selected without claiming verification', (
    tester,
  ) async {
    final record = basisFood(snapshot: basisSnapshot(ownerKey: 'source-owner'));
    Object? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPremiumTrustedVisionFoodMatchDialog(
                context,
                recognizedName: 'Recognized cooked food',
                foods: [record],
                evidenceOwnerKey: 'source-owner',
              ).then((value) => chosen = value),
              child: const Text('Open source'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open source'));
    await tester.pumpAndSettle();
    final use = find.byKey(const Key('premium-vision-use-food'));
    expect(tester.widget<FilledButton>(use).onPressed, isNull);
    await tester.tap(find.text(record.name));
    await tester.pump();
    expect(tester.widget<FilledButton>(use).onPressed, isNotNull);
    expect(find.textContaining('not catalog-verified'), findsOneWidget);
    await tester.tap(use);
    await tester.pumpAndSettle();
    expect(chosen, same(record));
  });

}
