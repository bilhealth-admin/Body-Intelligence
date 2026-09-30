import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: dashboard resolves the same scroll physics as More', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const DashboardShell(child: SizedBox(height: 1800)),
        ),
      );

      final dashboardScrollable = tester.widget<Scrollable>(
        find.descendant(
          of: find.byKey(const Key('dashboard-scroll-view')),
          matching: find.byType(Scrollable),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: ListView(children: const [SizedBox(height: 1800)]),
        ),
      );
      final moreScrollable = tester.widget<Scrollable>(find.byType(Scrollable));

      expect(dashboardScrollable.physics.runtimeType, moreScrollable.physics.runtimeType);
      if (platform == TargetPlatform.iOS) {
        expect(dashboardScrollable.physics, isA<BouncingScrollPhysics>());
      } else {
        expect(dashboardScrollable.physics, isA<ClampingScrollPhysics>());
      }
      expect(tester.takeException(), isNull);
    });
  }
}
