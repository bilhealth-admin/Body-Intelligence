import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget shellApp({
  Locale locale = const Locale('en'),
  String initialLocation = '/dashboard',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (_, _, child) => ResponsiveAppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('dashboard'))),
          ),
          GoRoute(
            path: '/daily-log',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('daily-log'))),
          ),
          GoRoute(
            path: '/nutrition',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('nutrition'))),
          ),
          GoRoute(
            path: '/history',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('history'))),
          ),
          GoRoute(
            path: '/analytics',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('analytics'))),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('settings'))),
          ),
        ],
      ),
    ],
  );
  return MaterialApp.router(
    locale: locale,
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  testWidgets('compact shell uses bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('wide shell uses navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('compact shell destination tap navigates to analytics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('analytics'), findsOneWidget);
  });

  testWidgets('selected index uses exact path matching boundaries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(shellApp(initialLocation: '/daily-log'));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
  });

  testWidgets('unknown shell route defaults selected index to dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(shellApp(initialLocation: '/dashboard'));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
  });

  testWidgets('navigation and quick add semantics are present', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Primary navigation'), findsOneWidget);
    expect(find.bySemanticsLabel('Quick Add'), findsWidgets);
  });

  testWidgets('Arabic quick add localizes unavailable AI boundary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(shellApp(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('إضافة سريعة'), findsOneWidget);
    expect(find.text('إضافة طعام'), findsOneWidget);
    expect(find.text('إضافة ماء'), findsOneWidget);
    expect(find.text('مسح الباركود'), findsOneWidget);
    expect(
      find.text('غير متاح حتى يتم إعداد مصدر موثوق لبيانات الباركود.'),
      findsOneWidget,
    );
    expect(find.text('اسأل BIL'), findsOneWidget);
    expect(
      find.text(
        'غير متاح حتى إعداد حدود موافقة الذكاء الاصطناعي وتحديد المعدل على الخادم.',
      ),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.text('إضافة سريعة'))),
      TextDirection.rtl,
    );
  });

  testWidgets(
    'English quick add shows explicit unavailable capability boundaries',
    (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(shellApp(locale: const Locale('en')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Quick Add'), findsOneWidget);
      expect(find.text('Scan barcode'), findsOneWidget);
      expect(
        find.text(
          'Unavailable until a verified barcode data source is configured.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ask BIL'), findsOneWidget);
      expect(
        find.text(
          'Unavailable until the server-side AI consent and rate-limit boundary is configured.',
        ),
        findsOneWidget,
      );
    },
  );
}
