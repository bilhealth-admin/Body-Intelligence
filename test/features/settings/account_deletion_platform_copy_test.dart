import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/settings/account_deletion_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final tag in BilLocalePolicy.productionTags) {
      testWidgets(
        'deletion billing names only the device store $platform $tag',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              locale: BilLocalePolicy.localeFromTag(tag),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const AccountDeletionPage(),
            ),
          );
          await tester.pumpAndSettle();
          final displayed = tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data ?? '')
              .join(' ');
          expect(
            displayed,
            contains(
              platform == TargetPlatform.iOS ? 'App Store' : 'Google Play',
            ),
          );
          expect(
            displayed,
            isNot(
              contains(
                platform == TargetPlatform.iOS ? 'Google Play' : 'App Store',
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
