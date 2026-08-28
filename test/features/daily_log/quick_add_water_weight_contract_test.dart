import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quick add copy resolves for every extended production locale', () {
    const keys = <String>[
      'Quick Add',
      'Choose an action and go directly to it.',
      'Log food',
      'Scan barcode',
      'Log food by voice',
      'Analyze meal photo',
      'Water',
      'Weight',
      'Exercise library',
      'Daily notes',
      'Search or create food',
    ];
    expect(AppLocalizations.supportedLocales, hasLength(25));
    for (final locale in AppLocalizations.supportedLocales) {
      if (const {'ar', 'en', 'fr', 'es', 'tr'}.contains(locale.languageCode)) {
        continue;
      }
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final key in keys) {
        expect(
          ExtendedRuntimeCopy.values[key]?.containsKey(tag),
          isTrue,
          reason: '$key needs a direct catalog entry for $tag',
        );
        final translated = ExtendedRuntimeCopy.values[key]![tag]!.trim();
        expect(translated, isNotEmpty);
        const reviewedIdentity = {'Water|nl'};
        if (!reviewedIdentity.contains('$key|$tag')) {
          expect(
            translated,
            isNot(key),
            reason: '$key must not silently fall back to English for $tag',
          );
        }
        expect(
          RuntimeCopy.resolve(key, tag),
          isNotNull,
          reason: '$key must resolve for $tag',
        );
      }
    }
  });

  test('weight check-in never invents a personal default', () {
    final source = File(
      'lib/features/daily_check_in/daily_check_in_page.dart',
    ).readAsStringSync();
    expect(source, contains("display?.toStringAsFixed(1) ?? '—'"));
    expect(source, contains('final current = weightKg == null'));
    expect(source, contains('profileState.isLoading'));
    expect(source, contains('systemState.hasError'));
    expect(source, contains('ActionableErrorState'));
    expect(source, contains('PopScope('));
    expect(source, contains('canPop: !saving && !skipping'));
    expect(source, contains('kilograms > 500'));
    expect(source, contains('.clamp(20, 500)'));
    expect(source, contains('if (saving || skipping) return;'));
    expect(source, isNot(contains('?? 60')));
    expect(source, isNot(contains("text: '60'")));
  });

  test('water entry validates bounds and blocks duplicate submissions', () {
    final waterPage = File(
      'lib/features/daily_log/daily_water_page.dart',
    ).readAsStringSync();
    final section = File(
      'lib/features/daily_log/presentation/daily_log_input_sections.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/features/daily_log/water_mutation_coordinator.dart',
    ).readAsStringSync();
    expect(
      waterPage,
      contains('if (saving || !await ensureDiaryOpen()) return;'),
    );
    expect(waterPage, contains('amount > 5000'));
    expect(coordinator, contains('if (_busy) return'));
    expect(coordinator, contains('onBusyChanged(true)'));
    expect(coordinator, contains('onBusyChanged(false)'));
    expect(waterPage, contains('Water could not be saved. Try again.'));
    expect(waterPage, contains('canPop: false'));
    expect(waterPage, contains('if (!didPop && !saving) leave();'));
    expect(section, contains('enabled: !saving'));
    expect(section, contains('onPressed: saving ? null'));
  });
}
