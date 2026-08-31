import 'dart:io';

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
    expect(
      bilQuickAddAuthoredCopy['Premium']!.values,
      everyElement('Premium'),
      reason: 'Premium is a protected brand and must never be translated.',
    );
  });

  test('production shell wires the approved subtle Quick Add photo', () {
    final source = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();
    expect(
      source,
      contains(
        'assets/images/onboarding_2026/'
        'bil_onboarding_meal_quick_add_photo_v1.webp',
      ),
    );
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
        find.byKey(const Key('quick-add-blue-background')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('quick-add-wordmark')), findsOneWidget);
      expect(find.byKey(const Key('quick-add-photo-hero')), findsNothing);
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

  const sizes = <Size>[Size(320, 568), Size(390, 844), Size(430, 932)];
  const scales = <double>[1, 1.6, 2];
  const locales = <Locale>[Locale('en'), Locale('ar')];
  const themes = <ThemeMode>[ThemeMode.light, ThemeMode.dark];
  var cartesianCount = 0;
  for (final size in sizes) {
    for (final scale in scales) {
      for (final locale in locales) {
        for (final themeMode in themes) {
          cartesianCount++;
          testWidgets(
            'Quick Add Cartesian ${size.width.toInt()}x${size.height.toInt()} '
            '${locale.languageCode} ${themeMode.name} ${scale}x',
            (tester) async {
              final semantics = tester.ensureSemantics();
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);

              await tester.pumpWidget(
                MaterialApp(
                  locale: locale,
                  themeMode: themeMode,
                  theme: ThemeData(colorSchemeSeed: const Color(0xFF087F73)),
                  darkTheme: ThemeData(
                    brightness: Brightness.dark,
                    colorSchemeSeed: const Color(0xFF79D8C8),
                  ),
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
                      ).copyWith(textScaler: TextScaler.linear(scale)),
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

              final wordmark = find.byKey(const Key('quick-add-wordmark'));
              expect(wordmark, findsOneWidget);
              expect(
                tester.getSemantics(wordmark).label,
                'Body Intelligence Log',
              );
              final brandText = tester.widget<Text>(
                find.descendant(
                  of: wordmark,
                  matching: find.text('BODY INTELLIGENCE LOG'),
                ),
              );
              expect(brandText.style?.color, const Color(0xFF050505));
              final wordmarkRect = tester.getRect(wordmark);
              expect(wordmarkRect.left, greaterThanOrEqualTo(0));
              expect(wordmarkRect.right, lessThanOrEqualTo(size.width));
              for (var index = 0; index < 4; index++) {
                final action = find.byKey(Key('quick-add-primary-$index'));
                expect(action, findsOneWidget);
                expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
              }
              for (var index = 0; index < 3; index++) {
                final action = find.byKey(Key('quick-add-secondary-$index'));
                expect(action, findsOneWidget);
                expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
              }
              final firstIcon = tester.widget<Icon>(
                find
                    .descendant(
                      of: find.byKey(const Key('quick-add-primary-0')),
                      matching: find.byType(Icon),
                    )
                    .first,
              );
              expect(
                firstIcon.color,
                themeMode == ThemeMode.dark
                    ? const Color(0xFFAFC6FF)
                    : const Color(0xFF1D4ED8),
              );
              expect(tester.takeException(), isNull);
              semantics.dispose();
            },
          );
        }
      }
    }
  }
  assert(cartesianCount == 36);
}
