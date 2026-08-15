import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/settings/settings_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'settings authored copy is complete in all five production languages',
    () {
      expect(SettingsCopy.catalogsBalanced, isTrue);
      expect(SettingsCopy.supportedLanguageCodes, {
        'ar',
        'en',
        'fr',
        'es',
        'tr',
      });

      final english = SettingsCopy.catalog(const Locale('en'));
      for (final languageCode in const ['fr', 'es', 'tr']) {
        final localized = SettingsCopy.catalog(Locale(languageCode));
        expect(localized.keys.toSet(), english.keys.toSet());
        for (final entry in localized.entries) {
          expect(entry.value, isNot(equals(english[entry.key])));
          expect(
            RegExp(r'[\u0600-\u06ff]').hasMatch(entry.value),
            isFalse,
            reason: '$languageCode leaked Arabic for ${entry.key}',
          );
        }
      }
    },
  );

  test('settings page contains no Arabic-English locale branch', () {
    final source = [
      'lib/features/settings/settings_page.dart',
      'lib/features/settings/settings_page_actions.dart',
      'lib/features/settings/help_center_page.dart',
      'lib/features/settings/trust_support_page.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    expect(source, isNot(contains("languageCode == 'ar'")));
    expect(source, isNot(contains('arabic ?')));
    expect(source, contains('Comment BIL calcule-t-il mes objectifs ?'));
    expect(source, contains('¿Cómo calcula BIL mis objetivos?'));
    expect(source, contains('BIL hedeflerimi nasıl hesaplar?'));
    expect(source, contains('Confiance et assistance'));
    expect(source, contains('Confianza y ayuda'));
    expect(source, contains('Güven ve destek'));
  });

  test('unreviewed runtime copy never falls back to Arabic in fr es or tr', () {
    const authoredEnglish = 'A deliberately unreviewed settings sentence';
    for (final languageCode in const ['fr', 'es', 'tr']) {
      final strings = AppLocalizations(Locale(languageCode));
      final value = strings.text(authoredEnglish);
      expect(value, authoredEnglish);
      expect(RegExp(r'[\u0600-\u06ff]').hasMatch(value), isFalse);
    }
  });
}
