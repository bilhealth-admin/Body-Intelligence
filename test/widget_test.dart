import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/features/onboarding/widgets/welcome_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      home: WelcomeStep(onContinue: _noop),
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
      home: WelcomeStep(onContinue: _noop),
    );
  }
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

void _noop() {}

void main() {
  testWidgets('Arabic welcome uses the approved personal-model message', (
    tester,
  ) async {
    await tester.pumpWidget(buildWelcomeApp(const Locale('ar')));
    await tester.pumpAndSettle();

    const body =
        'ابدأ رحلتك نحو جسم أكثر صحة وقوة وذكاء مع نموذج شخصي يتعلم من بياناتك.';
    expect(find.text(body), findsOneWidget);
    expect(find.text('متابعة'), findsOneWidget);
    expect(
      find.byKey(const Key('onboarding-welcome-continue')),
      findsOneWidget,
    );

    final direction = Directionality.of(tester.element(find.text(body)));
    expect(direction, TextDirection.rtl);
  });

  testWidgets('English welcome uses the approved personal-model message', (
    tester,
  ) async {
    await tester.pumpWidget(buildWelcomeApp(const Locale('en')));
    await tester.pumpAndSettle();

    const body =
        'Start your journey toward a healthier, stronger, smarter body with a personal model that learns from your data.';
    expect(find.text(body), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    final direction = Directionality.of(tester.element(find.text(body)));
    expect(direction, TextDirection.ltr);
  });

  testWidgets('Welcome honors the persisted French locale', (tester) async {
    final service = _WidgetSettingsService('fr');
    await tester.pumpWidget(_buildReactiveWelcomeApp(service));
    await tester.pumpAndSettle();

    const body =
        'Commencez votre parcours vers un corps plus sain, plus fort et plus intelligent avec un modèle personnel qui apprend de vos données.';
    expect(find.text(body), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text(body))),
      TextDirection.ltr,
    );
    expect(service.value.localeCode, 'fr');
  });
}
