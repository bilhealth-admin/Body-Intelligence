import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => Scaffold(body: DashboardTopBar(onProfile: () {})),
        ),
        GoRoute(
          path: '/dashboard/preferences',
          builder: (_, _) =>
              const Scaffold(body: Text('dashboard-preferences-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('header keeps full controls while omitting Today and date', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
    expect(find.text('Aug 6, 2026'), findsNothing);
    expect(find.text('Welcome'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('profile uses a neutral account avatar by default', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-default-profile-avatar')),
      findsOneWidget,
    );
  });

  testWidgets('Edit opens dashboard customization', (tester) async {
    await pumpDashboard(tester);

    expect(find.byIcon(Icons.dashboard_customize_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard-edit-today')));
    await tester.pumpAndSettle();

    expect(find.text('dashboard-preferences-destination'), findsOneWidget);
  });

  const sizes = <Size>[Size(320, 568), Size(430, 932)];
  const locales = <Locale>[Locale('en'), Locale('ar')];
  const themes = <ThemeMode>[ThemeMode.light, ThemeMode.dark];
  const scales = <double>[1, 2];
  var identityCases = 0;
  for (final size in sizes) {
    for (final locale in locales) {
      for (final themeMode in themes) {
        for (final scale in scales) {
          identityCases++;
          testWidgets('dashboard wordmark ${size.width.toInt()} '
              '${locale.languageCode} ${themeMode.name} ${scale}x', (
            tester,
          ) async {
            final semantics = tester.ensureSemantics();
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                themeMode: themeMode,
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                supportedLocales: const [Locale('en'), Locale('ar')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(body: DashboardTopBar(onProfile: () {})),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final wordmark = find.byKey(const Key('dashboard-wordmark'));
            expect(wordmark, findsOneWidget);
            expect(
              tester.getSemantics(wordmark).label,
              contains('Body Intelligence Log'),
            );
            final rect = tester.getRect(wordmark);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            final brandText = tester.widget<Text>(
              find.descendant(
                of: wordmark,
                matching: find.text('BODY INTELLIGENCE LOG'),
              ),
            );
            expect(brandText.style?.color, const Color(0xFF050505));
            expect(tester.takeException(), isNull);
            semantics.dispose();
          });
        }
      }
    }
  }
  assert(identityCases == 16);

  var localeCases = 0;
  for (final locale in AppLocalizations.supportedLocales) {
    for (final scale in const <double>[1, 2]) {
      localeCases++;
      testWidgets(
        'dashboard identity fits 320px ${locale.toLanguageTag()} ${scale}x',
        (tester) async {
          final semantics = tester.ensureSemantics();
          tester.view.physicalSize = const Size(320, 568);
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
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(body: DashboardTopBar(onProfile: () {})),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final wordmark = find.byKey(const Key('dashboard-wordmark'));
          expect(wordmark, findsOneWidget);
          expect(tester.getSemantics(wordmark).label, 'Body Intelligence Log');
          expect(find.byKey(const Key('dashboard-edit-today')), findsOneWidget);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }
  assert(localeCases == 50);
}
