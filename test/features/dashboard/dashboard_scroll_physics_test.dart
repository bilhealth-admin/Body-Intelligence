import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform: dashboard resolves the same scroll physics as More',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: const DashboardShell(child: SizedBox(height: 1800)),
          ),
        );

        final dashboardPosition = tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byKey(const Key('dashboard-scroll-view')),
                matching: find.byType(Scrollable),
              ),
            )
            .position;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: ListView(children: const [SizedBox(height: 1800)]),
          ),
        );
        final morePosition = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;

        expect(
          dashboardPosition.physics.runtimeType,
          morePosition.physics.runtimeType,
        );
        if (platform == TargetPlatform.iOS) {
          expect(dashboardPosition.physics, isA<BouncingScrollPhysics>());
        } else {
          expect(dashboardPosition.physics, isA<ClampingScrollPhysics>());
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
