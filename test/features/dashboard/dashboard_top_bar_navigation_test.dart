import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_top_bar.dart';
import 'package:flutter/material.dart';
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
}
