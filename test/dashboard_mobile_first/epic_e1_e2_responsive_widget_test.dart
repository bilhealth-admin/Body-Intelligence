import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget subject() {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PremiumDashboardBenchmark(
            arabic: false,
            actionTitle: 'Log water',
            actionReason: 'Hydration is the best next action.',
            actionEvidence: 'Water log is incomplete.',
            confidence: 'Useful',
            onAction: () {},
            dailyIntelligence: const SizedBox(height: 120),
            hero: const SizedBox(height: 160),
            progressSection: const SizedBox(height: 120),
            personalHealthAi: const ColoredBox(
              color: Colors.transparent,
              child: Center(child: Text('Personal Health AI test panel')),
            ),
            connectedHealth: const SizedBox(height: 100),
            bodyTwinSummary:
                'Current weight 93.4 kg · BMI 28.5 · Body fat 24.0%',
            bodyTwinEvidence: 'Cautious range 0.4 to 0.8 kg/week',
            nutritionSummary: 'Protein evidence is available.',
            nutritionEvidence: 'Three meals logged.',
            trendSummary: 'Weight trend is decreasing.',
            trendEvidence: 'Seven comparable weigh-ins.',
            loggingItems: const [
              DashboardLoggingItem(label: 'Weight', recorded: true),
              DashboardLoggingItem(label: 'Meals', recorded: true),
              DashboardLoggingItem(label: 'Water', recorded: false),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> setViewport(
    WidgetTester tester, {
    required double width,
    required double height,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('phone stacks both intelligence cards at full width', (
    tester,
  ) async {
    await setViewport(tester, width: 390, height: 2200);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    final ai = find.byKey(const Key('dashboard-mobile-personal-ai-slot'));
    final insights = find.byKey(const Key('dashboard-mobile-insights-slot'));

    expect(ai, findsOneWidget);
    expect(insights, findsOneWidget);
    expect(tester.getSize(ai).width, greaterThan(380));
    expect(tester.getSize(insights).width, greaterThan(380));
    expect(
      tester.getTopLeft(insights).dy,
      greaterThan(tester.getTopLeft(ai).dy),
    );
    expect(tester.getSize(ai).height, inInclusiveRange(420, 500));
    expect(tester.getSize(insights).height, inInclusiveRange(420, 500));
    expect(
      find.byKey(const Key('dashboard-mobile-body-twin-snapshot')),
      findsOneWidget,
    );
    expect(find.textContaining('Current weight 93.4 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet preserves side-by-side intelligence layout', (
    tester,
  ) async {
    await setViewport(tester, width: 800, height: 1600);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    final ai = find.byKey(const Key('dashboard-tablet-personal-ai-slot'));
    final insights = find.byKey(const Key('dashboard-tablet-insights-slot'));

    expect(ai, findsOneWidget);
    expect(insights, findsOneWidget);
    expect(tester.getTopLeft(ai).dy, tester.getTopLeft(insights).dy);
    expect(
      tester.getTopLeft(insights).dx,
      greaterThan(tester.getTopLeft(ai).dx),
    );
    expect(
      find.byKey(const Key('dashboard-mobile-body-twin-snapshot')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
