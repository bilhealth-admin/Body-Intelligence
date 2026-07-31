import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_analytics_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject() {
    return const Scaffold(
      body: DashboardAnalyticsCenter(
        title: 'Analytics Center',
        weightJourney: SizedBox(
          key: Key('weight-journey'),
          height: 80,
          child: Text('Weight journey'),
        ),
        weeklyProgress: SizedBox(
          key: Key('weekly-progress'),
          height: 80,
          child: Text('Weekly progress'),
        ),
        bodyProfile: SizedBox(
          key: Key('body-profile'),
          height: 80,
          child: Text('Body profile'),
        ),
      ),
    );
  }

  Future<void> setViewport(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: subject()));
  }

  testWidgets('phone keeps the body profile out of the analytics branch', (
    tester,
  ) async {
    await setViewport(tester, size: const Size(500, 800));

    expect(find.text('Analytics Center'), findsOneWidget);
    expect(find.byKey(const Key('weight-journey')), findsOneWidget);
    expect(find.byKey(const Key('weekly-progress')), findsOneWidget);
    expect(find.byKey(const Key('body-profile')), findsNothing);
    expect(find.byType(Column), findsWidgets);
  });

  testWidgets('tablet places body profile before the analytics heading', (
    tester,
  ) async {
    await setViewport(tester, size: const Size(800, 1000));

    expect(find.byKey(const Key('body-profile')), findsOneWidget);
    expect(find.text('Analytics Center'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('body-profile'))).dy,
      lessThan(tester.getTopLeft(find.text('Analytics Center')).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('weight-journey'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('weekly-progress'))).dy),
    );
  });

  testWidgets('wide layout preserves row order, flex, and numeric direction', (
    tester,
  ) async {
    await setViewport(tester, size: const Size(1400, 900));

    expect(find.text('Analytics Center'), findsNothing);
    expect(find.byKey(const Key('weight-journey')), findsOneWidget);
    expect(find.byKey(const Key('weekly-progress')), findsOneWidget);
    expect(find.byKey(const Key('body-profile')), findsOneWidget);

    final rowFinder = find.descendant(
      of: find.byType(DashboardAnalyticsCenter),
      matching: find.byType(Row),
    );
    final row = tester.widget<Row>(rowFinder);
    expect(row.crossAxisAlignment, CrossAxisAlignment.start);
    final expanded = row.children.whereType<Expanded>().toList();
    expect(expanded.map((item) => item.flex), [6, 5, 9]);

    final localDirectionality = find.descendant(
      of: find.byType(DashboardAnalyticsCenter),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Directionality &&
            widget.textDirection == TextDirection.ltr,
      ),
    );
    expect(localDirectionality, findsOneWidget);
  });
}
