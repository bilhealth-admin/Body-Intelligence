import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_meals_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/closure_surface_capture.dart';
import '../../visual_closure/visual_evidence_font.dart';
import '../nutrition/food_basis_fixtures.dart';
import 'daily_log_nutrition_fixtures.dart';

void main() {
  for (final locale in ['ar', 'en']) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 390.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'compact meal rows $locale ${brightness.name} $width $scale',
            (tester) async {
              final opened = <String>[];
              final semantics = tester.ensureSemantics();
              try {
                await tester.runAsync(loadVisualEvidenceFont);
                final meal = diaryMeal([modernDiaryItem()]);
                final list = DailyMealsList(
                  arabic: locale == 'ar',
                  compactRows: true,
                  meals: AsyncData([meal]),
                  onAdd: opened.add,
                  onEdit: (_, _) async {},
                  onActions: (_, _) async {},
                );
                await pumpDiaryEvidence(
                  tester,
                  list,
                  language: locale,
                  brightness: brightness,
                  width: width,
                  scale: scale,
                  repaintKey: GlobalKey(),
                  theme: visualEvidenceTheme(
                    brightness == Brightness.light
                        ? BilFlagshipTheme.light(isArabic: locale == 'ar')
                        : BilFlagshipTheme.dark(isArabic: locale == 'ar'),
                    fontFamily: 'NotoArabicEvidence',
                  ),
                );
                expect(
                  find.text(locale == 'ar' ? 'افتح الوجبة' : 'Open meal'),
                  findsNothing,
                );
                expect(find.byType(FilledButton), findsNothing);
                expect(find.byType(PopupMenuButton<String>), findsNothing);
                expect(
                  diaryText(tester, 'daily-meal-totals-breakfast'),
                  locale == 'ar' ? '123 سعرة' : '123 cal',
                );
                expect(
                  diaryText(tester, 'daily-meal-totals-dinner'),
                  locale == 'ar' ? 'لم تسجل بعد' : 'Not logged yet',
                );
                for (final type in ['breakfast', 'lunch', 'dinner', 'snack']) {
                  final row = find.byKey(Key('daily-meal-log-$type'));
                  await tester.ensureVisible(row);
                  final node = tester.getSemantics(
                    find.byKey(Key('daily-meal-access-$type')),
                  );
                  expect(
                    node.getSemanticsData().hasAction(SemanticsAction.tap),
                    isTrue,
                  );
                  expect(
                    node.getSemanticsData().flagsCollection.isButton,
                    isTrue,
                  );
                  expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
                  if (scale == 1) {
                    expect(tester.getSize(row).height, lessThan(100));
                  }
                  await tester.tap(row);
                  await tester.pump();
                }
                expect(opened, ['breakfast', 'lunch', 'dinner', 'snack']);
                expect(tester.takeException(), isNull);
                if (width == 390 && scale == 1 || width == 320 && scale == 2) {
                  await captureClosureSurface(
                    tester,
                    find.byType(DailyMealsList),
                    'today-meals-$locale-${brightness.name}-${width.round()}-${scale.round()}x',
                  );
                }
              } finally {
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }

  testWidgets('compact meal unknown stays unknown and zero remains zero', (
    tester,
  ) async {
    for (final calories in <double?>[null, 0]) {
      final meal = diaryMeal([
        modernDiaryItem(
          values: {...basisNutrients, FoodNutrient.calories: calories},
        ),
      ]);
      await pumpDiaryEvidence(
        tester,
        DailyMealsList(
          arabic: false,
          compactRows: true,
          meals: AsyncData([meal]),
          onAdd: (_) {},
          onEdit: (_, _) async {},
          onActions: (_, _) async {},
        ),
      );
      expect(
        diaryText(tester, 'daily-meal-totals-breakfast'),
        calories == null ? '— cal' : '0 cal',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('compact row keyboard opens the same meal once', (tester) async {
    final opened = <String>[];
    await pumpDiaryEvidence(
      tester,
      DailyMealsList(
        arabic: false,
        compactRows: true,
        meals: const AsyncData([]),
        onAdd: opened.add,
        onEdit: (_, _) async {},
        onActions: (_, _) async {},
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, ['breakfast']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long Arabic meal name remains reachable at 320 and 2x', (
    tester,
  ) async {
    var opened = false;
    const title = 'إفطار عربي طويل يحتاج أكثر من سطر دون تصغير الخط';
    await pumpDiaryEvidence(
      tester,
      ProviderScope(
        overrides: [
          diaryMealNamesProvider.overrideWithValue(
            const AsyncData([title, null, null, null]),
          ),
        ],
        child: DailyMealsList(
          arabic: true,
          compactRows: true,
          meals: const AsyncData([]),
          onAdd: (_) => opened = true,
          onEdit: (_, _) async {},
          onActions: (_, _) async {},
        ),
      ),
      language: 'ar',
      width: 320,
      scale: 2,
    );
    expect(find.text(title), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily-meal-log-breakfast')));
    await tester.pump();
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
