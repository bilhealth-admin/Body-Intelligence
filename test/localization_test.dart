import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
