import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime measurements preserve values and localize units safely', () {
    expect(AppLocalizations(const Locale('ar')).text('-0.8 kg'), '-0.8 كجم');
    for (final languageCode in const ['en', 'fr', 'es', 'tr']) {
      expect(AppLocalizations(Locale(languageCode)).text('-0.8 kg'), '-0.8 kg');
    }
  });

  test(
    'unknown runtime copy degrades safely instead of crashing the screen',
    () {
      final strings = AppLocalizations(const Locale('ar'));
      expect(
        strings.text('server copy that has not completed review'),
        'server copy that has not completed review',
      );
    },
  );

  test(
    'Arabic primary settings and history copy does not fall back to English',
    () {
      final strings = AppLocalizations(const Locale('ar'));
      const keys = [
        'Targets and plan',
        'Personal experiments',
        'Decision Memory',
        'Connected capabilities',
        'Local Mode is active. No data is uploaded.',
        'Reset all local data?',
        'Could not load weight history',
        'More data needed',
        'Cloud accounts are not configured in this build. No credentials will be accepted or stored.',
        'Manual barcode lookup',
        'No matching foods. Create a custom food.',
        'Verified catalog record',
      ];
      for (final key in keys) {
        expect(
          strings.text(key),
          isNot(key),
          reason: 'Missing Arabic for $key',
        );
      }
    },
  );
}
