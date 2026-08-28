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
  Widget? dashboardChild,
  TextScaler textScaler = TextScaler.noScaling,
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
            builder: (_, _) => Scaffold(
              body: dashboardChild ?? const Center(child: Text('dashboard')),
            ),
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
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
    await tester.pumpWidget(shellApp(initialLocation: '/intelligence-center'));
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
    await tester.pumpWidget(shellApp(initialLocation: '/intelligence-center'));
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

  testWidgets('compact dock shows Dashboard, Quick Add, and More only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('shell-dashboard-destination')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shell-quick-add')), findsOneWidget);
    expect(find.byKey(const Key('shell-more-destination')), findsOneWidget);
    expect(find.text('Diary'), findsNothing);
    expect(find.text('Progress'), findsNothing);

    await tester.tap(find.byKey(const Key('shell-more-destination')));
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets('hidden routes do not falsely select a compact destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp(initialLocation: '/daily-log'));
    await tester.pumpAndSettle();

    final dashboardSemantics = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byKey(const Key('shell-dashboard-destination')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    final moreSemantics = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byKey(const Key('shell-more-destination')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(dashboardSemantics.properties.selected, isFalse);
    expect(moreSemantics.properties.selected, isFalse);
  });

  testWidgets('navigation and quick add semantics are present', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Primary navigation'), findsOneWidget);
    expect(find.byKey(const Key('shell-quick-add')), findsOneWidget);
  });

  testWidgets('compact dock keeps one integrated quick add control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp(initialLocation: '/settings'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.byKey(const Key('shell-dashboard-destination')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shell-quick-add')), findsOneWidget);
    expect(find.byKey(const Key('shell-more-destination')), findsOneWidget);
  });

  testWidgets('compact hidden routes retain the integrated quick add dock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp(initialLocation: '/daily-log'));
    await tester.pumpAndSettle();

    final navigationRect = tester.getRect(
      find.byKey(const Key('glass-bottom-navigation')),
    );
    final quickAddRect = tester.getRect(
      find.byKey(const Key('shell-quick-add')),
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('shell-quick-add')), findsOneWidget);
    expect(navigationRect.contains(quickAddRect.center), isTrue);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      '${locale.languageCode} quick add occupies a reserved navigation slot',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          shellApp(
            locale: locale,
            dashboardChild: const Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                key: Key('dashboard-bottom-data-card'),
                width: double.infinity,
                height: 120,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final quickAddRect = tester.getRect(
          find.byKey(const Key('shell-quick-add')),
        );
        final dataRect = tester.getRect(
          find.byKey(const Key('dashboard-bottom-data-card')),
        );
        final navigationRect = tester.getRect(
          find.byKey(const Key('glass-bottom-navigation')),
        );
        expect(quickAddRect.overlaps(dataRect), isFalse);
        expect(navigationRect.contains(quickAddRect.center), isTrue);
      },
    );
  }

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      '${locale.languageCode} compact dock mirrors safely at 160% text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          shellApp(locale: locale, textScaler: const TextScaler.linear(1.6)),
        );
        await tester.pumpAndSettle();

        final dashboardRect = tester.getRect(
          find.byKey(const Key('shell-dashboard-destination')),
        );
        final quickAddRect = tester.getRect(
          find.byKey(const Key('shell-quick-add')),
        );
        final moreRect = tester.getRect(
          find.byKey(const Key('shell-more-destination')),
        );

        expect(dashboardRect.height, greaterThanOrEqualTo(48));
        expect(quickAddRect.width, greaterThanOrEqualTo(48));
        expect(quickAddRect.height, greaterThanOrEqualTo(48));
        expect(moreRect.height, greaterThanOrEqualTo(48));
        if (locale.languageCode == 'ar') {
          expect(dashboardRect.center.dx, greaterThan(quickAddRect.center.dx));
          expect(quickAddRect.center.dx, greaterThan(moreRect.center.dx));
        } else {
          expect(dashboardRect.center.dx, lessThan(quickAddRect.center.dx));
          expect(quickAddRect.center.dx, lessThan(moreRect.center.dx));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('quick add sheet uses canonical motion timing', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell-quick-add')));
    await tester.pump();
    expect(find.byKey(const Key('quick-add-half-sheet')), findsOneWidget);
    await tester.tapAt(const Offset(16, 16));
    await tester.pump(PremiumMotionTokens.navigationDuration);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-add-half-sheet')), findsNothing);
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
    expect(find.byKey(const Key('quick-add-half-sheet')), findsOneWidget);
    expect(find.text('الوزن'), findsNothing);
    expect(find.text('تسجيل الطعام'), findsOneWidget);
    expect(find.text('الماء'), findsNothing);
    expect(find.text('مكتبة التمارين'), findsOneWidget);
    expect(find.textContaining('البحث عن طعام'), findsOneWidget);
    expect(find.textContaining('مسح الباركود'), findsOneWidget);
    expect(find.text('اسأل BIL'), findsNothing);
    expect(
      Directionality.of(tester.element(find.text('تسجيل الطعام'))),
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
    expect(find.byKey(const Key('quick-add-half-sheet')), findsOneWidget);
    expect(find.text('Weight'), findsNothing);
    expect(find.text('Log food'), findsOneWidget);
    expect(find.text('Water'), findsNothing);
    expect(find.text('Exercise library'), findsOneWidget);
    expect(find.text('Search or create food'), findsOneWidget);
    expect(find.textContaining('Scan barcode'), findsOneWidget);
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
