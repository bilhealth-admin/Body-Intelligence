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
  testWidgets('Arabic V10 welcome uses RTL and approved content', (
    tester,
  ) async {
    await tester.pumpWidget(buildWelcomeApp(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('مرحبًا بك'), findsOneWidget);
    expect(find.text('ابدأ رحلتك'), findsOneWidget);
    expect(find.text('خصوصية تامة'), findsOneWidget);
    expect(find.text('يعمل دون إنترنت'), findsOneWidget);
    expect(find.text('نتائج قابلة للتفسير'), findsOneWidget);
    expect(
      find.text('لا يلزم إنشاء حساب، ولا يتم رفع أي بيانات.'),
      findsOneWidget,
    );

    final direction = Directionality.of(tester.element(find.text('مرحبًا بك')));
    expect(direction, TextDirection.rtl);
  });

  testWidgets('English V10 welcome uses LTR and approved content', (
    tester,
  ) async {
    await tester.pumpWidget(buildWelcomeApp(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Start your journey'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Explainable'), findsOneWidget);
    expect(find.text('Understand every insight'), findsOneWidget);
    expect(find.text('Science first'), findsOneWidget);
    expect(
      find.text('No account required. Nothing is uploaded.'),
      findsOneWidget,
    );
    expect(find.text('Optional account and sync'), findsNothing);

    final direction = Directionality.of(tester.element(find.text('Welcome')));
    expect(direction, TextDirection.ltr);
  });

  testWidgets('Welcome language selection updates direction and persists', (
    tester,
  ) async {
    final service = _WidgetSettingsService('en');
    await tester.pumpWidget(_buildReactiveWelcomeApp(service));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text('مرحبًا بك'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('مرحبًا بك'))),
      TextDirection.rtl,
    );
    expect(service.value.localeCode, 'ar');
    expect(find.text('Welcome'), findsNothing);
  });
}
