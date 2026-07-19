import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/onboarding/widgets/welcome_step.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildWelcomeApp(Locale locale) {
  return ProviderScope(
    overrides: [
      appSettingsServiceProvider.overrideWithValue(
        _WidgetSettingsService(locale.languageCode),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: WelcomeStep(onContinue: () {})),
    ),
  );
}

Widget _buildReactiveWelcomeApp(_WidgetSettingsService service) {
  return ProviderScope(
    overrides: [appSettingsServiceProvider.overrideWithValue(service)],
    child: const _ReactiveWelcomeHarness(),
  );
}

class _ReactiveWelcomeHarness extends ConsumerWidget {
  const _ReactiveWelcomeHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Locale(ref.watch(appSettingsProvider).localeCode);
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: WelcomeStep(onContinue: _noop)),
    );
  }

  static void _noop() {}
}

class _WidgetSettingsService extends AppSettingsService {
  _WidgetSettingsService(String locale)
    : value = AppSettings(localeCode: locale, themeMode: 'system');

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}

void main() {
  testWidgets('Arabic default locale shows RTL onboarding text', (
    tester,
  ) async {
    await tester.pumpWidget(buildWelcomeApp(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('مرحبًا بك في BIL'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
    final direction = Directionality.of(
      tester.element(find.text('مرحبًا بك في BIL')),
    );
    expect(direction, TextDirection.rtl);
  });

  testWidgets('English locale shows LTR onboarding text', (tester) async {
    await tester.pumpWidget(buildWelcomeApp(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to BIL'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Understand every insight'), findsOneWidget);
    expect(find.text('Private and useful offline'), findsOneWidget);
    expect(find.text('Honest about uncertainty'), findsOneWidget);
    expect(find.text('Optional account and sync'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    final direction = Directionality.of(
      tester.element(find.text('Welcome to BIL')),
    );
    expect(direction, TextDirection.ltr);
  });

  testWidgets('Welcome language selection updates direction and persists', (
    tester,
  ) async {
    final service = _WidgetSettingsService('en');
    await tester.pumpWidget(_buildReactiveWelcomeApp(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text('مرحبًا بك في BIL'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('مرحبًا بك في BIL'))),
      TextDirection.rtl,
    );
    expect(service.value.localeCode, 'ar');
    expect(find.text('Welcome to BIL'), findsNothing);
  });
}
