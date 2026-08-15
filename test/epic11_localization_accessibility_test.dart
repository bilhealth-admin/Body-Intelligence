import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/feature_strings.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemorySettingsStore implements SettingsStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

Widget _localizedHarness(Locale locale, {double textScale = 1}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: BilFlagshipTheme.light(isArabic: locale.languageCode == 'ar'),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).get('settings')),
        ),
        body: SafeArea(
          child: ListView(
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(AppLocalizations.of(context).get('welcome_back')),
              ),
              FilledButton(
                onPressed: () {},
                child: Text(AppLocalizations.of(context).get('save')),
              ),
              Text(FeatureStrings.of(context).get('weekly_report')),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test(
    'all production catalogs use the complete 25-locale contract',
    () {
      expect(AppLocalizations.supportedLocales, hasLength(25));
      expect(RuntimeCopy.supported, hasLength(25));
      expect(AppLocalizations.baseCatalogsBalanced, isTrue);
      expect(FeatureStrings.catalogsBalanced, isTrue);
      expect(RuntimeCopy.balanced, isTrue);
      for (final translations in RuntimeCopy.values.values) {
        expect(
          translations.keys.toSet(),
          const <String>{'ar', 'en', 'fr', 'es', 'tr'},
        );
        expect(translations.values, everyElement(isNotEmpty));
      }
    },
  );

  test(
    'locale formatters preserve bidi isolation, plurals, and local numbers',
    () {
      final arabic = AppLocalizations(const Locale('ar'));
      final french = AppLocalizations(const Locale('fr'));
      final turkish = AppLocalizations(const Locale('tr'));
      expect(AppLocalizations.isRtl(const Locale('ar')), isTrue);
      expect(AppLocalizations.isRtl(const Locale('tr')), isFalse);
      expect(
        arabic.isolate('user@example.com'),
        '\u2068user@example.com\u2069',
      );
      expect(french.number(1234.5), isNot('1,234.5'));
      expect(turkish.number(1234.5), contains(','));
      expect(
        french.plural(0, zero: 'aucun jour', one: 'un jour', other: '# jours'),
        'aucun jour',
      );
    },
  );

  test(
    'language choice persists independently from account and user data',
    () async {
      final store = _MemorySettingsStore();
      final service = AppSettingsService(store: store);
      await service.save(
        AppSettings(
          localeCode: 'tr',
          themeMode: 'dark',
          highContrast: true,
          reduceMotion: true,
        ),
      );
      final restored = await service.load();
      expect(restored.localeCode, 'tr');
      expect(restored.themeMode, 'dark');
      expect(restored.highContrast, isTrue);
      expect(restored.reduceMotion, isTrue);
      expect(jsonDecode(store.value!)['localeCode'], 'tr');
    },
  );

  test('regional and script locale choices round-trip exactly', () async {
    for (final tag in const ['pt-BR', 'pt-PT', 'zh-Hans', 'zh-Hant']) {
      final store = _MemorySettingsStore();
      final service = AppSettingsService(store: store);
      await service.save(AppSettings(localeCode: tag, themeMode: 'light'));
      final restored = await service.load();
      expect(restored.localeCode, tag, reason: tag);
      expect(jsonDecode(store.value!)['localeCode'], tag, reason: tag);
    }
  });

  test('a fresh installation starts in English', () async {
    final service = AppSettingsService(store: _MemorySettingsStore());
    final settings = await service.load();
    expect(settings.localeCode, 'en');
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      '${locale.languageCode} renders translated reachable copy at 200%',
      (tester) async {
        await tester.pumpWidget(_localizedHarness(locale, textScale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(AppLocalizations(locale).get('settings')),
          findsOneWidget,
        );
        expect(find.text(AppLocalizations(locale).get('save')), findsOneWidget);
        final direction = tester.widget<Directionality>(
          find.byType(Directionality).first,
        );
        expect(
          direction.textDirection,
          AppLocalizations.isRtl(locale)
              ? TextDirection.rtl
              : TextDirection.ltr,
        );
        final buttonSize = tester.getSize(find.byType(FilledButton));
        expect(buttonSize.height, greaterThanOrEqualTo(44));
        expect(buttonSize.width, greaterThanOrEqualTo(44));
      },
    );
  }
}
