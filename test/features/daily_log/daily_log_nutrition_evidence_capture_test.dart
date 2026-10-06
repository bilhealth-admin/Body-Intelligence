import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_meals_list.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_summary_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';
import '../nutrition/food_basis_fixtures.dart';
import 'daily_log_nutrition_fixtures.dart';

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final output = Platform.environment['BIL_DIARY_EVIDENCE_CAPTURE_DIR'];
  if (output == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets('native diary evidence capture $language dark=$dark', (
        tester,
      ) async {
        final key = GlobalKey();
        final theme = visualEvidenceTheme(
          dark
              ? BilFlagshipTheme.dark(isArabic: language == 'ar')
              : BilFlagshipTheme.light(isArabic: language == 'ar'),
          fontFamily: language == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence',
        );
        final item = calorieOnlyDiaryItem();
        final meal = diaryMeal(
          [item],
          foods: {
            item.foodId: basisFood().copyWith(
              name: language == 'ar' ? 'إضافة سعرات فقط' : 'Add calories only',
              isCustom: true,
            ),
          },
        );
        Future<void> pump(Widget child) => pumpDiaryEvidence(
          tester,
          child,
          language: language,
          theme: theme,
          repaintKey: key,
        );
        final suffix = '$language-${dark ? 'dark' : 'light'}';
        await pump(
          DailyLogSnapshot(
            arabic: language == 'ar',
            meals: [meal],
            water: const [],
            calorieGoal: 2000,
            carbsGoal: 250,
            proteinGoal: 100,
            fatGoal: 70,
          ),
        );
        expect(
          diaryText(tester, 'daily-summary-calories-value'),
          contains('1905'),
        );
        for (final macro in ['carbs', 'protein', 'fat']) {
          expect(diaryText(tester, 'daily-summary-$macro-grams'), '—');
        }
        await _capture(tester, key, 'diary-calorie-only-$suffix');
        await pump(
          Column(
            children: [
              DailyMealDetailSummary(meal: meal, calorieGoal: 2000),
              const SizedBox(height: 12),
              DailyMealDetailItems(
                meal: meal,
                showFoodTimestamps: false,
                onEdit: (_, _) async {},
                onActions: (_, _) async {},
              ),
            ],
          ),
        );
        expect(diaryText(tester, 'daily-food-insights-1'), 'C —  P —  F —');
        expect(tester.takeException(), isNull);
        await _capture(tester, key, 'diary-meal-evidence-$suffix');
      });
    }
  }
}
