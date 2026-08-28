import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_locale_copy.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quick Add release copy is complete for all 25 locales', () {
    for (final key in bilQuickAddReleaseKeys) {
      final translations = bilQuickAddAuthoredCopy[key];
      expect(translations, isNotNull, reason: 'Missing Quick Add key: $key');
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        expect(
          translations![tag]?.trim(),
          isNotEmpty,
          reason: 'Missing Quick Add translation: $key / $tag',
        );
      }
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    testWidgets('Quick Add $tag fits 390x844 at 160%', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: Scaffold(
                body: BilQuickAddSheet(
                  onFood: () {},
                  onBarcode: () {},
                  onVoice: () {},
                  onPhoto: () {},
                  onExercise: () {},
                  onNotes: () {},
                  onSearch: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('quick-add-spring-background')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('quick-add-low-visibility-veil')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('quick-add-half-sheet')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('quick-add-half-sheet'))).height,
        lessThanOrEqualTo(844 * .60),
      );
      for (var index = 0; index < 4; index++) {
        expect(find.byKey(Key('quick-add-primary-$index')), findsOneWidget);
      }
      for (var index = 0; index < 3; index++) {
        expect(find.byKey(Key('quick-add-secondary-$index')), findsOneWidget);
      }
      expect(find.text('Quick Add'), findsNothing);
      expect(find.text('Water'), findsNothing);
      expect(find.text('Weight'), findsNothing);
    });
  }
}
