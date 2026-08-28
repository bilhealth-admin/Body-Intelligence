import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/onboarding/widgets/welcome_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('Welcome V10 ${locale.languageCode} visual baseline', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_welcome(locale));
      await tester.pumpAndSettle();
      await settleVisualAssetImages(tester);

      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(WelcomeStep),
        matchesGoldenFile('goldens/welcome_v10_${locale.languageCode}.png'),
      );
    });
  }
}

Widget _welcome(Locale locale) => ProviderScope(
  overrides: [
    appSettingsServiceProvider.overrideWithValue(
      _GoldenSettingsService(locale.languageCode),
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
    theme: visualEvidenceTheme(
      BilFlagshipTheme.light(isArabic: locale.languageCode == 'ar'),
      fontFamily: locale.languageCode == 'ar'
          ? 'NotoArabicEvidence'
          : 'RobotoEvidence',
    ),
    builder: (context, child) => visualEvidenceTextSurface(
      child,
      fontFamily: locale.languageCode == 'ar'
          ? 'NotoArabicEvidence'
          : 'RobotoEvidence',
    ),
    home: WelcomeStep(onContinue: _noop),
  ),
);

void _noop() {}

class _GoldenSettingsService extends AppSettingsService {
  _GoldenSettingsService(String localeCode)
    : settings = AppSettings(localeCode: localeCode, themeMode: 'light');

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings next) async => settings = next;
}
