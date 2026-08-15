import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_rollout_manifest.dart';
import 'package:body_intelligence_log/app/localization/feature_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _surface(Locale locale, double scale) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(context.strings.get('app_title'))),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(context.strings.get('welcome_back')),
              Text(context.strings.get('dashboard')),
              Text(context.strings.get('daily_log')),
              Text(context.strings.get('nutrition')),
              Text(context.strings.get('settings')),
              Text(FeatureStrings.of(context).get('weekly_report')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {},
                child: Text(context.strings.get('save')),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    for (final scale in const [1.0, 1.3]) {
      testWidgets('$tag smoke at ${scale}x', (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_surface(locale, scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(FilledButton), findsOneWidget);
        expect(find.text(AppLocalizations(locale).get('settings')), findsOneWidget);
        final direction = tester.widget<Directionality>(
          find.byType(Directionality).first,
        );
        expect(
          direction.textDirection,
          BilLocalePolicy.isRtlTag(tag) ? TextDirection.rtl : TextDirection.ltr,
        );
      });
    }
  }

  test('smoke matrix covers every exact production target', () {
    expect(
      AppLocalizations.supportedLocales
          .map(BilLocalePolicy.canonicalTag)
          .toSet(),
      BilLocaleRolloutManifest.releaseTargets25,
    );
  });
}
