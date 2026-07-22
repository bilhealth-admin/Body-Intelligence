import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_composition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('composition stacks regions below wide breakpoint', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardComposition(
            hero: SizedBox(key: Key('hero-region'), height: 100),
            content: SizedBox(key: Key('content-region'), height: 100),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('dashboard-composition-stacked')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboard-composition-wide')), findsNothing);
    expect(find.byKey(const Key('hero-region')), findsOneWidget);
    expect(find.byKey(const Key('content-region')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('composition uses two regions at wide breakpoint', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardComposition(
            hero: SizedBox(key: Key('hero-region'), height: 100),
            content: SizedBox(key: Key('content-region'), height: 100),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('dashboard-composition-wide')), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-composition-stacked')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
