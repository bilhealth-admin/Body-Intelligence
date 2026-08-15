import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_image_guide_launcher.dart';
import 'package:body_intelligence_log/features/nutrition/providers/meal_vision_usage_provider.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_vision_usage_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('meal photo action opens step one and returns false safely', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealVisionUsageProvider.overrideWithValue(
            const AsyncData(MealVisionUsageSnapshot.unavailable()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await openMealImageGuide(context),
                child: const Text('Meal photo action'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Meal photo action'));
    await tester.pumpAndSettle();
    expect(find.text('Meal Scan'), findsOneWidget);
    expect(find.text('STEP 1 OF 4'), findsOneWidget);
    expect(find.text('Scan your entire meal'), findsOneWidget);
    expect(find.byKey(const Key('meal-vision-usage')), findsOneWidget);
    final next = find.byKey(const Key('meal-image-guide-next'));
    expect(tester.widget<FilledButton>(next).onPressed, isNull);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Meal Scan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Daily Log photo initial action uses the production guide launcher', () {
    final page = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/features/daily_log/daily_log_page_actions.dart',
    ).readAsStringSync();
    expect(page, contains("case 'photo':"));
    expect(page, contains('await _analyzeMealImage();'));
    expect(actions, contains('await openMealImageGuide(context)'));
  });
}
