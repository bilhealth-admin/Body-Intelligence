import 'package:body_intelligence_log/shared/widgets/secondary_page_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('direct secondary route falls back to dashboard', (tester) async {
    final router = _router(initialLocation: '/secondary');
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.text('Secondary'), findsOneWidget);
    await tester.tap(find.byKey(const Key('secondary-page-back')));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('pushed secondary route pops to previous page', (tester) async {
    final router = _router(initialLocation: '/dashboard');
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open secondary'));
    await tester.pumpAndSettle();
    expect(find.text('Secondary'), findsOneWidget);

    await tester.tap(find.byKey(const Key('secondary-page-back')));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('dashboard action always returns to dashboard', (tester) async {
    final router = _router(initialLocation: '/secondary');
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('secondary-page-dashboard')));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('Arabic navigation exposes localized tooltips', (tester) async {
    final router = _router(initialLocation: '/secondary');
    await tester.pumpWidget(_app(router, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    final back = tester.widget<IconButton>(
      find.byKey(const Key('secondary-page-back')),
    );
    final dashboard = tester.widget<IconButton>(
      find.byKey(const Key('secondary-page-dashboard')),
    );

    expect(back.tooltip, 'رجوع');
    expect(dashboard.tooltip, 'العودة إلى لوحة اليوم');
  });
}

Widget _app(GoRouter router, {Locale locale = const Locale('en')}) {
  return MaterialApp.router(
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: router,
  );
}

GoRouter _router({required String initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => Scaffold(
        body: Column(
          children: [
            const Text('Dashboard'),
            TextButton(
              onPressed: () => context.push('/secondary'),
              child: const Text('Open secondary'),
            ),
          ],
        ),
      ),
    ),
    GoRoute(
      path: '/secondary',
      builder: (context, state) => const Scaffold(
        appBar: SecondaryPageAppBar(title: Text('Secondary')),
        body: SizedBox.shrink(),
      ),
    ),
  ],
);
