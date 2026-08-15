import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/app/theme/premium_motion_tokens.dart';
import 'package:body_intelligence_log/features/profile/profile_settings_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget shellApp({
  Locale locale = const Locale('en'),
  String initialLocation = '/dashboard',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/profile-settings',
        builder: (_, _) => const ProfileSettingsPage(),
      ),
      GoRoute(
        path: '/wellness/workouts',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('workout-library'))),
      ),
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
          GoRoute(
            path: '/intelligence-center',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('ai-coach'))),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith((ref) => const Stream.empty()),
    ],
    child: MaterialApp.router(
      locale: locale,
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
  testWidgets('compact shell uses bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('glass-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const Key('glass-top-navigation')), findsNothing);
  });

  testWidgets('wide shell uses unified top navigation', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('glass-top-navigation')), findsOneWidget);
    expect(find.byKey(const Key('glass-bottom-navigation')), findsNothing);
    for (final label in [
      'Today',
      'Diary',
      'Discover',
      'Progress',
      'Insights',
      'More',
      'Profile',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('compact AI route does not mount the dashboard quick add', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      shellApp(initialLocation: '/intelligence-center'),
    );
    await tester.pumpAndSettle();
    expect(find.text('ai-coach'), findsOneWidget);
    expect(find.byKey(const Key('shell-quick-add')), findsNothing);
  });

  testWidgets('wide AI route does not cover its composer with quick add', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      shellApp(initialLocation: '/intelligence-center'),
    );
    await tester.pumpAndSettle();
    expect(find.text('ai-coach'), findsOneWidget);
    expect(find.byKey(const Key('shell-quick-add')), findsNothing);
  });

  testWidgets('visible desktop profile control opens the profile form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shell-profile-control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ProfileSettingsPage), findsOneWidget);
    expect(find.text('settings'), findsNothing);
  });

  testWidgets('compact shell destination tap navigates to progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('history'), findsOneWidget);
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

  testWidgets('navigation and quick add semantics are present', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Primary navigation'), findsOneWidget);
    expect(find.byTooltip('Quick Add'), findsOneWidget);
  });

  testWidgets('quick add sheet uses canonical motion timing', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell-quick-add')));
    await tester.pump();
    expect(find.text('Quick Add'), findsOneWidget);
    await tester.tapAt(const Offset(16, 16));
    await tester.pump(PremiumMotionTokens.navigationDuration);
    await tester.pumpAndSettle();
    expect(find.text('Quick Add'), findsNothing);
  });

  testWidgets('Arabic quick add exposes only implemented capabilities', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell-quick-add')));
    await tester.pumpAndSettle();
    expect(find.text('إضافة سريعة'), findsOneWidget);
    expect(find.text('وزن'), findsOneWidget);
    expect(find.text('تسجيل الطعام'), findsOneWidget);
    expect(find.text('الماء'), findsOneWidget);
    expect(find.text('مكتبة التمارين'), findsOneWidget);
    expect(find.textContaining('البحث عن طعام'), findsOneWidget);
    expect(find.text('مسح الباركود'), findsOneWidget);
    expect(find.text('اسأل BIL'), findsNothing);
    expect(
      Directionality.of(tester.element(find.text('وزن'))),
      TextDirection.rtl,
    );
  });

  testWidgets('English quick add exposes only implemented capabilities', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell-quick-add')));
    await tester.pumpAndSettle();
    expect(find.text('Quick Add'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Log food'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Exercise library'), findsOneWidget);
    expect(find.text('Search or create food'), findsOneWidget);
    expect(find.text('Scan barcode'), findsOneWidget);
    expect(find.text('Ask BIL'), findsNothing);
  });

  testWidgets('quick add exercise opens the real workout library route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell-quick-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercise library'));
    await tester.pumpAndSettle();
    expect(find.text('workout-library'), findsOneWidget);
  });
}
