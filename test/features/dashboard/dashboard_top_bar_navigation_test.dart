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
          builder: (_, _) => Scaffold(
            body: DashboardTopBar(
              arabic: false,
              now: DateTime(2026, 8, 6),
              displayName: 'Kazem',
              onProfile: () {},
            ),
          ),
        ),
        GoRoute(
          path: '/notification-settings',
          builder: (_, _) => const Scaffold(
            body: Text('notification-settings-destination'),
          ),
        ),
        GoRoute(
          path: '/dashboard/preferences',
          builder: (_, _) => const Scaffold(
            body: Text('dashboard-preferences-destination'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('notification control opens notification settings', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('notification-settings-destination'), findsOneWidget);
  });

  testWidgets('Edit opens dashboard customization', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('dashboard-edit-today')));
    await tester.pumpAndSettle();

    expect(find.text('dashboard-preferences-destination'), findsOneWidget);
  });
}
