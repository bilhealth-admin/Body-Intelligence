import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget shellApp({Locale locale = const Locale('en')}) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (_, _, child) => ResponsiveAppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const SizedBox(key: Key('content')),
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
}
