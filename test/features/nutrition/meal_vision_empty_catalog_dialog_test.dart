import 'package:body_intelligence_log/data/database/app_database.dart'
    show Food;
import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_premium_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'food_basis_fixtures.dart';

void main() {
  testWidgets(
    'initially empty public catalog returns null without opening or confirming',
    (tester) async {
      var completed = false;
      TrustedVisionFoodSelection? selection;
      await _mount(tester, const [], (value) {
        completed = true;
        selection = value;
      });
      expect(completed, isTrue);
      expect(selection, isNull);
      expect(find.byKey(const Key('premium-vision-use-food')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'catalog cleared during real public dialog shows missing source without crash or confirmation',
    (tester) async {
      final foods = <Food>[basisFood().copyWith(verified: true)];
      var completed = false;
      TrustedVisionFoodSelection? selection;
      await _mount(tester, foods, (value) {
        completed = true;
        selection = value;
      });
      final action = find.byKey(const Key('premium-vision-use-food'));
      expect(action, findsOneWidget);
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      foods.clear();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('vision-required-details')), findsOneWidget);
      expect(find.byKey(const Key('vision-missing-source')), findsOneWidget);
      expect(completed, isFalse);
      expect(selection, isNull);
      await tester.tap(find.byKey(const Key('vision-required-cancel')));
      await tester.pumpAndSettle();
      expect(action, findsOneWidget);
      expect(completed, isFalse);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(selection, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mount(
  WidgetTester tester,
  List<Food> foods,
  void Function(TrustedVisionFoodSelection?) onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              onResult(
                await showEditableTrustedVisionFoodMatchDialog(
                  context,
                  recognizedName: 'Recognized food',
                  foods: foods,
                  reviewedAmount: 40,
                  reviewedUnit: 'g',
                ),
              );
            },
            child: const Text('Open source review'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open source review'));
  await tester.pumpAndSettle();
}
