import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'visual_evidence_font.dart';

Widget _app({required Locale locale, required ThemeMode themeMode}) {
  final evidenceFont = locale.languageCode == 'ar'
      ? 'NotoArabicEvidence'
      : 'RobotoEvidence';
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/wellness/workouts',
        builder: (_, _) => const Scaffold(body: Text('workout-library')),
      ),
      ShellRoute(
        builder: (_, _, child) => ResponsiveAppShell(child: child),
        routes: [
          for (final path in const [
            '/dashboard',
            '/daily-log',
            '/nutrition',
            '/history',
            '/analytics',
            '/settings',
          ])
            GoRoute(path: path, builder: (_, _) => const SizedBox.expand()),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith((ref) => const Stream.empty()),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: locale,
      themeMode: themeMode,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF087FCE),
        fontFamily: evidenceFont,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF54D9FF),
        fontFamily: evidenceFont,
      ),
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final scenario in const [
    ('en_light', Locale('en'), ThemeMode.light),
    ('ar_dark', Locale('ar'), ThemeMode.dark),
  ]) {
    testWidgets('quick add ${scenario.$1} production visual', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(locale: scenario.$2, themeMode: scenario.$3),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shell-quick-add')));
      await tester.pumpAndSettle();
      await settleVisualAssetImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/quick_add_${scenario.$1}_phone.png'),
      );
    });
  }
}
