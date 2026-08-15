import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/settings/trust_support_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trust support cold-renders both Chinese script locales', (
    tester,
  ) async {
    for (final locale in const <Locale>[
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const TrustSupportPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());
      expect(find.text('Trust & support'), findsNothing);
      expect(find.byType(TrustSupportPage), findsOneWidget);
    }
  });
}
