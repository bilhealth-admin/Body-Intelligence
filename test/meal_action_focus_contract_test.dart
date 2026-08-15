import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete-meal action requests meal-focused diary context', () {
    final dashboard = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final diary = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();
    final mealEntry = File(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ).readAsStringSync();

    expect(
      dashboard,
      contains(
        "context.go('/daily-log?meal=breakfast&focus=meal&from=%2Fdashboard')",
      ),
    );
    expect(
      router,
      contains("focusMealEntry: state.uri.queryParameters['focus'] == 'meal'"),
    );
    expect(diary, contains('Scrollable.ensureVisible('));
    expect(mealEntry, contains('key: mealEntryKey'));
    expect(diary, contains('this.focusMealEntry = false'));
    expect(diary, contains('if (!widget.focusMealEntry) ...['));
    expect(diary, contains('if (widget.focusMealEntry && !mealFocusApplied)'));
    expect(diary, contains('addPostFrameCallback((_) => _focusMealEntry())'));
  });

  test(
    'a changed diary action is dispatched when the routed page is reused',
    () {
      final diary = File(
        'lib/features/daily_log/daily_log_page.dart',
      ).readAsStringSync();

      expect(
        diary,
        contains('void didUpdateWidget(covariant DailyLogPage oldWidget)'),
      );
      expect(
        diary,
        contains('oldWidget.initialAction != widget.initialAction'),
      );
      expect(diary, contains('initialActionApplied = false'));
      expect(diary, contains('initialActionInFlight != null'));
      expect(diary, contains('widget.initialAction != action'));
      expect(diary, contains('WidgetsBinding.instance.addPostFrameCallback('));
      expect(diary, contains('(_) => _applyInitialAction(),'));
    },
  );

  test('meal search copy is explicit across all 25 production locales', () {
    const authored = <String>{'en', 'ar', 'fr', 'es', 'tr'};
    for (final tag in BilLocalePolicy.productionTags) {
      if (authored.contains(tag)) continue;
      final search = RuntimeCopy.resolve('Search foods', tag);
      final hint = RuntimeCopy.resolve(
        'Start typing a food name or scan its barcode.',
        tag,
      );
      expect(search, isNotNull, reason: tag);
      expect(search, isNot(equals('Search foods')), reason: tag);
      expect(hint, isNotNull, reason: tag);
      expect(
        hint,
        isNot(equals('Start typing a food name or scan its barcode.')),
        reason: tag,
      );
    }
  });

  test('extended meal search surface has no missing runtime copy keys', () {
    const authored = <String>{'en', 'ar', 'fr', 'es', 'tr'};
    const surface = <String>[
      'Your usual meals — nothing is added without your confirmation',
      'Search English, Arabic, keyword, or barcode',
      'Start typing a food name or scan its barcode.',
      'Favorites',
      'Recently used',
      'No result after correction. Open the food catalog to download more.',
      'Verified nutrition record',
      'Unverified nutrition record',
      'Choose a serving',
      'Save to favorites',
      'Remove from favorites',
    ];
    for (final tag in BilLocalePolicy.productionTags) {
      if (authored.contains(tag)) continue;
      for (final english in surface) {
        final translated = RuntimeCopy.resolve(english, tag);
        expect(translated, isNotNull, reason: '$tag: $english');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $english');
      }
    }
  });
}
