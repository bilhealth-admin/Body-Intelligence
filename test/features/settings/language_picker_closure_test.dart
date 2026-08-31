import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_names.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:body_intelligence_log/features/auth/auth_language_selector.dart';
import 'package:body_intelligence_log/features/settings/language_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one exact 25-locale order is shared with English first', () {
    expect(BilLocaleNames.englishFirstAlphabeticalTags, const [
      'en',
      'ar',
      'bn',
      'zh-Hans',
      'zh-Hant',
      'nl',
      'fr',
      'de',
      'hi',
      'id',
      'it',
      'ja',
      'ko',
      'ms',
      'fa',
      'pl',
      'pt-BR',
      'pt-PT',
      'ru',
      'es',
      'th',
      'tr',
      'uk',
      'ur',
      'vi',
    ]);
    expect(BilLocaleNames.native, hasLength(25));
    expect(
      BilLocaleNames.native.keys.toList(growable: false),
      BilLocaleNames.englishFirstAlphabeticalTags,
    );
    expect(
      BilLocaleNames.englishFirstAlphabeticalTags.toSet(),
      BilLocaleNames.native.keys.toSet(),
    );
    expect(
      BilLocaleNames.englishFirstAlphabeticalTags.toSet(),
      BilLocalePolicy.productionTags,
    );

    final auth = File(
      'lib/features/auth/auth_language_selector.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/language_settings_page.dart',
    ).readAsStringSync();
    expect(
      auth,
      contains(
        'const orderedKeys = BilLocaleNames.englishFirstAlphabeticalTags',
      ),
    );
    expect(
      settings,
      contains(
        'static const orderedTags = BilLocaleNames.englishFirstAlphabeticalTags',
      ),
    );
  });

  test(
    'fresh install is English and a persisted choice wins on restart',
    () async {
      final store = _MemorySettingsStore();
      final fresh = AppSettingsService(store: store);
      expect((await fresh.load()).localeCode, 'en');

      await fresh.save(AppSettings(localeCode: 'fa', themeMode: 'light'));
      final restarted = AppSettingsService(store: store);
      expect((await restarted.load()).localeCode, 'fa');
    },
  );

  testWidgets(
    'Auth ignores OS locale on fresh install and persists selection before pop',
    (tester) async {
      final store = _MemorySettingsStore();
      final service = AppSettingsService(store: store);
      await tester.pumpWidget(
        _app(
          locale: const Locale('ar'),
          service: service,
          home: const Scaffold(body: AuthLanguageSelector()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('auth-language-selector-label')))
            .data,
        'English',
      );
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('auth-language-selector-row'))),
        ),
        TextDirection.ltr,
      );

      await tester.tap(find.byKey(const Key('auth-language-selector')));
      await tester.pumpAndSettle();
      final arabicRow = find.byKey(const Key('auth-language-option-row-ar'));
      final arabicLabel = find.byKey(
        const Key('auth-language-option-label-ar'),
      );
      expect(arabicRow, findsOneWidget);
      expect(Directionality.of(tester.element(arabicRow)), TextDirection.ltr);
      final arabicText = tester.widget<Text>(arabicLabel);
      expect(arabicText.textDirection, TextDirection.rtl);
      expect(arabicText.textAlign, TextAlign.left);

      await tester.tap(arabicRow);
      await tester.pumpAndSettle();
      expect(arabicRow, findsNothing);
      expect((await service.load()).localeCode, 'ar');
      expect(
        tester
            .widget<Text>(find.byKey(const Key('auth-language-selector-label')))
            .data,
        'العربية',
      );

      final selectorLabel = find.byKey(
        const Key('auth-language-selector-label'),
      );
      final selectorArrow = find.byKey(
        const Key('auth-language-selector-arrow'),
      );
      expect(
        tester.widget<Text>(selectorLabel).textDirection,
        TextDirection.rtl,
      );
      expect(
        tester.getCenter(selectorArrow).dx,
        greaterThan(tester.getCenter(selectorLabel).dx),
      );

      await tester.tap(find.byKey(const Key('auth-language-selector')));
      await tester.pumpAndSettle();
      final selectedArabicLabel = find.byKey(
        const Key('auth-language-option-label-ar'),
      );
      final selectedArabicCheck = find.byKey(
        const Key('auth-language-option-check'),
      );
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('auth-language-option-row-ar'))),
        ),
        TextDirection.ltr,
      );
      expect(
        tester.getCenter(selectedArabicCheck).dx,
        greaterThan(tester.getCenter(selectedArabicLabel).dx),
      );
    },
  );

  testWidgets(
    'Auth saved locale wins over a different active Material locale',
    (tester) async {
      final store = _MemorySettingsStore();
      final service = AppSettingsService(store: store);
      await service.save(AppSettings(localeCode: 'ar', themeMode: 'light'));

      await tester.pumpWidget(
        _app(
          locale: const Locale('fr'),
          service: service,
          home: const Scaffold(body: AuthLanguageSelector()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('auth-language-selector-label')))
            .data,
        'العربية',
      );
    },
  );

  testWidgets(
    'Settings keeps LTR row geometry, saves, and pops after selection',
    (tester) async {
      final store = _MemorySettingsStore();
      final service = AppSettingsService(store: store);
      await service.save(AppSettings(localeCode: 'ar', themeMode: 'light'));

      await tester.pumpWidget(
        _app(
          locale: const Locale('ar'),
          service: service,
          home: const _LanguageSettingsHost(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-language-settings')));
      await tester.pumpAndSettle();

      final arabicRow = find.byKey(const Key('language-option-ar'));
      final arabicLabel = find.byKey(
        const Key('settings-language-option-label-ar'),
      );
      final selectedCheck = find.byKey(
        const Key('settings-language-option-check'),
      );
      expect(Directionality.of(tester.element(arabicRow)), TextDirection.ltr);
      final arabicText = tester.widget<Text>(arabicLabel);
      expect(arabicText.textDirection, TextDirection.rtl);
      expect(arabicText.textAlign, TextAlign.left);
      expect(
        tester.getCenter(selectedCheck).dx,
        greaterThan(tester.getCenter(arabicLabel).dx),
      );

      final frenchRow = find.byKey(const Key('language-option-fr'));
      await tester.ensureVisible(frenchRow);
      await tester.tap(frenchRow);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('open-language-settings')), findsOneWidget);
      expect(find.byType(LanguageSettingsPage), findsNothing);
      expect((await service.load()).localeCode, 'fr');
    },
  );
}

Widget _app({
  required Locale locale,
  required AppSettingsService service,
  required Widget home,
}) => ProviderScope(
  overrides: [appSettingsServiceProvider.overrideWithValue(service)],
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  ),
);

class _LanguageSettingsHost extends StatelessWidget {
  const _LanguageSettingsHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const Key('open-language-settings'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LanguageSettingsPage()),
        ),
        child: const Text('Open'),
      ),
    ),
  );
}

class _MemorySettingsStore implements SettingsStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
