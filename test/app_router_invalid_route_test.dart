import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/invalid_route_page.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production router installs a controlled error builder', () {
    final source = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(
      source,
      contains('errorBuilder: (_, _) => const InvalidRoutePage()'),
    );
    expect(source, isNot(contains('state.error')));
  });

  test('daily return route accepts only bounded internal destinations', () {
    final source = File('lib/app/router/app_router.dart').readAsStringSync();
    for (final path in ResponsiveAppShell.paths) {
      expect(ResponsiveAppShell.safeQuickAddReturnPath(path), path);
    }
    expect(
      ResponsiveAppShell.safeQuickAddReturnPath('/admin/ai-coach'),
      isNull,
    );
    expect(
      RegExp(
        r"returnPath:\s*state\.uri\.queryParameters\['from'\]",
      ).hasMatch(source),
      isFalse,
    );
    expect(
      RegExp(
        r'final returnPath = ResponsiveAppShell\.safeQuickAddReturnPath\(',
      ).allMatches(source).length,
      1,
    );
    expect(
      RegExp(r'returnPath:\s*returnPath').allMatches(source).length,
      2,
    );
    expect(
      RegExp(
        r'returnPath:\s*ResponsiveAppShell\.safeQuickAddReturnPath\(',
      ).allMatches(source).length,
      2,
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('invalid route copy resolves for $locale', (tester) async {
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
          home: const InvalidRoutePage(),
        ),
      );
      await tester.pumpAndSettle();

      final copy = AppLocalizations(locale).get('invalid_link');
      expect(copy.trim(), isNotEmpty);
      expect(copy, isNot('invalid_link'));
      expect(find.text(copy), findsOneWidget);
      expect(find.textContaining('GoException'), findsNothing);
      expect(find.textContaining('no routes for location'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
