import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Type> _physicsChain(ScrollPhysics physics) {
  final result = <Type>[];
  ScrollPhysics? current = physics;
  while (current != null) {
    result.add(current.runtimeType);
    current = current.parent;
  }
  return result;
}

void main() {
  // Final QA trigger after approved golden refresh.
  // QA trigger: validate refreshed visual references with current UI.
  // QA trigger: validate refreshed current UI references.
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
          _physicsChain(dashboardPosition.physics),
          _physicsChain(morePosition.physics),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
