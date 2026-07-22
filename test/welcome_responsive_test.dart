import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/features/onboarding/widgets/welcome_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = <({Size size, Locale locale})>[
    (size: Size(306, 650), locale: Locale('en')),
    (size: Size(306, 650), locale: Locale('ar')),
    (size: Size(390, 844), locale: Locale('en')),
    (size: Size(390, 844), locale: Locale('ar')),
    (size: Size(1280, 720), locale: Locale('en')),
    (size: Size(1280, 720), locale: Locale('ar')),
  ];

  for (final testCase in cases) {
    testWidgets('Welcome V10 has no overflow at '
        '${testCase.size.width.toInt()}x${testCase.size.height.toInt()} '
        '${testCase.locale.languageCode}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_welcome(testCase.locale));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WelcomeStep), findsOneWidget);
    });
  }
}

Widget _welcome(Locale locale) => ProviderScope(
  overrides: [
    appSettingsServiceProvider.overrideWithValue(
      _ResponsiveSettingsService(locale.languageCode),
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: WelcomeStep(onContinue: _noop),
  ),
);

void _noop() {}

class _ResponsiveSettingsService extends AppSettingsService {
  _ResponsiveSettingsService(String localeCode)
    : settings = AppSettings(localeCode: localeCode, themeMode: 'system');

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings next) async => settings = next;
}
