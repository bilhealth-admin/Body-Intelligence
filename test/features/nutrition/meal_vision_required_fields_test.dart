import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart'
    show Food;
import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_premium_review.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_gateway_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'food_basis_fixtures.dart';

Finder k(String value) => find.byKey(Key(value));
Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

MealImageAnalysis sample() => MealImageAnalysis(
  requestId: 'required-review',
  notice: 'Review',
  candidates: [
    MealImageCandidate(
      name: 'Recognized food',
      confidence: .9,
      evidence: 'Visible food',
      identificationProvider: 'fixture',
      modelRevision: '1',
      nutritionResolution: MealNutritionResolution.requiresVerifiedFoodMatch,
      amount: 100,
      unit: 'g',
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'incomplete Match opens required card and Cancel changes no form or confirmation',
    (tester) async {
      var confirms = 0;
      await openReview(
        tester,
        onConfirm: (_) async {
          confirms++;
          return const MealVisionReviewDecision.accepted();
        },
      );
      expect(
        tester.widget<FilledButton>(k('premium-vision-continue')).onPressed,
        isNotNull,
      );
      await tap(tester, k('premium-vision-continue'));
      expect(k('vision-required-details'), findsOneWidget);
      expect(k('vision-missing-stage'), findsOneWidget);
      expect(k('vision-missing-selection-0'), findsOneWidget);
      expect(confirms, 0);
      await tap(tester, k('vision-required-cancel'));
      expect(
        tester.widget<Checkbox>(k('premium-vision-select-0')).value,
        isFalse,
      );
      expect(
        tester.widget<ChoiceChip>(k('premium-vision-stage-before')).selected,
        isFalse,
      );
      expect(confirms, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing Eaten, amount and unit focus exact controls without inventing answers',
    (tester) async {
      var confirms = 0;
      await openReview(
        tester,
        onConfirm: (_) async {
          confirms++;
          return const MealVisionReviewDecision.accepted();
        },
      );
      await tap(tester, k('premium-vision-select-0'));
      await tap(tester, k('premium-vision-stage-before'));
      await tester.enterText(k('premium-vision-amount-0'), '');
      await tester.enterText(k('premium-vision-unit-0'), '');
      tester.testTextInput.hide();
      await tap(tester, k('premium-vision-continue'));
      for (final field in ['eaten-0', 'amount-0', 'unit-0']) {
        expect(k('vision-missing-$field'), findsOneWidget);
      }
      await tap(tester, k('vision-missing-amount-0'));
      final field = tester.widget<TextField>(k('premium-vision-amount-0'));
      expect(field.focusNode!.hasFocus, isTrue);
      expect(field.controller!.text, isEmpty);
      expect(
        tester.widget<ChoiceChip>(k('premium-vision-eaten-0')).selected,
        isFalse,
      );
      expect(confirms, 0);
      await tester.enterText(k('premium-vision-amount-0'), '40');
      tester.testTextInput.hide();
      await tap(tester, k('premium-vision-continue'));
      await tap(tester, k('vision-missing-unit-0'));
      expect(
        tester
            .widget<TextField>(k('premium-vision-unit-0'))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(
        tester.widget<TextField>(k('premium-vision-unit-0')).controller!.text,
        isEmpty,
      );
      expect(confirms, 0);
    },
  );

  testWidgets(
    'zero nonfinite and oversized portions cannot confirm through enabled Match',
    (tester) async {
      var confirms = 0;
      await openReview(
        tester,
        onConfirm: (_) async {
          confirms++;
          return const MealVisionReviewDecision.accepted();
        },
      );
      await tap(tester, k('premium-vision-select-0'));
      await tap(tester, k('premium-vision-eaten-0'));
      await tap(tester, k('premium-vision-stage-before'));
      for (final invalid in ['0', '-2', 'NaN', 'Infinity', '100001']) {
        await tester.enterText(k('premium-vision-amount-0'), invalid);
        tester.testTextInput.hide();
        await tap(tester, k('premium-vision-continue'));
        expect(k('vision-missing-amount-0'), findsOneWidget);
        expect(confirms, 0);
        await tap(tester, k('vision-required-cancel'));
      }
    },
  );

  testWidgets('valid Match confirms once and keeps busy guard', (tester) async {
    var confirms = 0;
    final held = Completer<MealVisionReviewDecision>();
    await openReview(
      tester,
      onConfirm: (_) {
        confirms++;
        return held.future;
      },
    );
    await tap(tester, k('premium-vision-select-0'));
    await tap(tester, k('premium-vision-eaten-0'));
    await tap(tester, k('premium-vision-stage-before'));
    await tester.ensureVisible(k('premium-vision-continue'));
    await tester.tap(k('premium-vision-continue'));
    await tester.pump();
    expect(confirms, 1);
    expect(
      tester.widget<FilledButton>(k('premium-vision-continue')).onPressed,
      isNull,
    );
    held.complete(const MealVisionReviewDecision.retry('Keep reviewing'));
    await tester.pumpAndSettle();
    expect(k('vision-required-details'), findsNothing);
    expect(find.text('Keep reviewing'), findsOneWidget);
    expect(confirms, 1);
  });

  testWidgets(
    'final source and incompatible piece unit are actionable without saving',
    (tester) async {
      final food = basisFood().copyWith(verified: true);
      TrustedVisionFoodSelection? result;
      await openFinal(
        tester,
        food: food,
        amount: 1,
        unit: 'piece',
        onResult: (value) => result = value,
      );
      expect(
        tester.widget<FilledButton>(k('premium-vision-use-food')).onPressed,
        isNotNull,
      );
      await tap(tester, k('premium-vision-use-food'));
      expect(k('vision-missing-source-${food.uuid}'), findsOneWidget);
      expect(result, isNull);
      await tap(tester, k('vision-required-cancel'));
      await tap(tester, find.text(food.name).first);
      await tap(tester, k('premium-vision-use-food'));
      expect(k('vision-missing-final-unit'), findsOneWidget);
      expect(result, isNull);
      await tap(tester, k('vision-missing-final-unit'));
      final unit = tester.widget<TextField>(k('premium-vision-final-unit'));
      expect(unit.focusNode!.hasFocus, isTrue);
      expect(unit.controller!.text, 'piece');
      await tester.enterText(k('premium-vision-final-amount'), '40');
      await tester.enterText(k('premium-vision-final-unit'), 'g');
      tester.testTextInput.hide();
      await tap(tester, k('premium-vision-use-food'));
      expect(result?.food, same(food));
      expect(result?.amount, 40);
      expect(result?.unit, 'g');
    },
  );

  testWidgets(
    'owner ABA while required modal is open cannot focus or confirm old review',
    (tester) async {
      const a = '11111111-1111-4111-8111-111111111111';
      const b = '22222222-2222-4222-8222-222222222222';
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await Supabase.initialize(
          url: 'https://vision-required.invalid',
          publishableKey: 'synthetic-public-key',
          debug: false,
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage(),
          ),
          httpClient: MockClient(
            (request) async =>
                throw StateError('No HTTP allowed in required-field review'),
          ),
        );
        await signIn(a);
      });
      var confirms = 0;
      try {
        await openReview(
          tester,
          onConfirm: (_) async {
            confirms++;
            return const MealVisionReviewDecision.accepted();
          },
        );
        await tap(tester, k('premium-vision-continue'));
        expect(k('vision-required-details'), findsOneWidget);
        await tester.runAsync(() async {
          await signIn(b);
          await signIn(a);
        });
        await tap(tester, k('vision-missing-stage'));
        expect(k('vision-required-details'), findsOneWidget);
        expect(confirms, 0);
        await tap(tester, k('vision-required-cancel'));
        await tap(tester, k('premium-vision-continue'));
        expect(k('vision-required-details'), findsNothing);
        expect(confirms, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => Supabase.instance.dispose());
      }
    },
  );

  testWidgets(
    'Arabic 320px 2x required details remain readable and focusable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openReview(tester, locale: const Locale('ar'), scale: 2);
      await tap(tester, k('premium-vision-continue'));
      expect(find.text('أكمل التفاصيل المطلوبة'), findsOneWidget);
      expect(k('vision-missing-stage'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, k('vision-missing-selection-0'));
      expect(
        tester
            .widget<Checkbox>(k('premium-vision-select-0'))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(
        tester.widget<Checkbox>(k('premium-vision-select-0')).value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> signIn(String owner) => Supabase.instance.client.auth
    .setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-token-$owner',
        'refresh_token': 'synthetic-refresh-$owner',
        'token_type': 'bearer',
        'user': {
          'id': owner,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    )
    .then((_) {});

Future<void> openReview(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double scale = 1,
  Future<MealVisionReviewDecision> Function(List<PremiumVisionSelection>)?
  onConfirm,
}) async {
  await mount(
    tester,
    locale,
    scale,
    (context) => showPremiumVisionReviewDialog(
      context,
      analysis: sample(),
      onConfirm: onConfirm,
    ),
  );
}

Future<void> openFinal(
  WidgetTester tester, {
  required Food food,
  required double amount,
  required String unit,
  required void Function(TrustedVisionFoodSelection?) onResult,
}) async {
  await mount(tester, const Locale('en'), 1, (context) async {
    final result = await showEditableTrustedVisionFoodMatchDialog(
      context,
      recognizedName: 'Recognized food',
      foods: [food],
      reviewedAmount: amount,
      reviewedUnit: unit,
    );
    onResult(result);
  });
}

Future<void> mount(
  WidgetTester tester,
  Locale locale,
  double scale,
  Future<dynamic> Function(BuildContext) open,
) async {
  await tester.pumpWidget(
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
              unawaited(open(context).then<void>((_) {}));
            },
            child: const Text('Open review'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open review'));
  await tester.pumpAndSettle();
}
