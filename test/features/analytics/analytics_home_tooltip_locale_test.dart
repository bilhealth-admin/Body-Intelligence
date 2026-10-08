import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/analytics/analytics_locale_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reviewed = <String, String>{
    'ar': 'العودة إلى الرئيسية',
    'en': 'Back to Home',
    'fr': 'Retour à l’accueil',
    'es': 'Volver al inicio',
    'tr': 'Ana sayfaya dön',
  };

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('Analytics Home return is readable in ${locale.toLanguageTag()}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Text(
                analyticsText(
                  context,
                  'Back to Home',
                  'العودة إلى الرئيسية',
                ),
                key: const Key('analytics-home-return-label'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = tester.widget<Text>(
        find.byKey(const Key('analytics-home-return-label')),
      ).data!;
      final tag = BilLocalePolicy.canonicalTag(locale);
      expect(label.trim(), isNotEmpty);
      if (tag != 'en') expect(label, isNot('Back to Home'));
      if (reviewed.containsKey(tag)) expect(label, reviewed[tag]);
      expect(label, isNot(contains('unavailable')));
      expect(tester.takeException(), isNull);
    });
  }
}
