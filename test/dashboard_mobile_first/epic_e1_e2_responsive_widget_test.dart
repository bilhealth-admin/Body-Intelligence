import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget subject({Set<String>? visibleSections, TargetPlatform? platform}) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PremiumDashboardBenchmark(
              arabic: false,
              actionTitle: 'Log water',
              actionReason: 'Hydration is the best next action.',
              actionEvidence: 'Water log is incomplete.',
              confidence: 'Useful',
              onAction: () {},
              dailyIntelligence: const SizedBox(
                key: Key('provided-daily-intelligence'),
                height: 120,
                child: Text('Daily Intelligence test panel'),
              ),
              hero: const SizedBox(
                key: Key('provided-dashboard-hero'),
                height: 160,
                child: Text('Dashboard hero test panel'),
              ),
              aiCoach: const SizedBox(
                key: Key('provided-secondary-ai-coach'),
                height: 80,
                child: Text('Secondary AI Coach test panel'),
              ),
              progressSection: const SizedBox(
                height: 120,
                child: Text('Today Summary test panel'),
              ),
              personalHealthAi: const ColoredBox(
                color: Colors.transparent,
                child: Center(child: Text('Personal Health AI test panel')),
              ),
              connectedHealth: const SizedBox(
                key: Key('connected-health-test-card'),
                height: 100,
              ),
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
              visibleSections:
                  visibleSections ?? DashboardSectionIds.all.toSet(),
            ),
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

  testWidgets('phone exposes Body Twin without duplicating workout entry', (
    tester,
  ) async {
    await setViewport(tester, width: 390, height: 2200);
    await tester.pumpWidget(subject(platform: TargetPlatform.android));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-mobile-summary-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard-mobile-workout-library-card')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('dashboard-mobile-body-twin-snapshot')),
      findsOneWidget,
    );
    final coachTop = tester.getTopLeft(
      find.byKey(const Key('dashboard-ai-coach-slot')),
    );
    final healthTop = tester.getTopLeft(
      find.byKey(const Key('connected-health-test-card')),
    );
    expect(find.byKey(const Key('connected-health-test-card')), findsOneWidget);
    expect(healthTop.dy, greaterThan(coachTop.dy));
    expect(find.byKey(const Key('provided-dashboard-hero')), findsOneWidget);
    expect(
      find.byKey(const Key('provided-daily-intelligence')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('provided-secondary-ai-coach')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard-personal-health-ai-slot')),
      findsOneWidget,
    );
    expect(find.text('Personal Health AI test panel'), findsOneWidget);
    expect(find.text('Today Summary test panel'), findsOneWidget);
    expect(find.textContaining('Current weight 93.4 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet keeps the complete current dashboard feature tree', (
    tester,
  ) async {
    await setViewport(tester, width: 800, height: 1600);
    await tester.pumpWidget(subject(platform: TargetPlatform.android));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-unified-adaptive-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard-current-content-rail')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboard-ai-coach-slot')), findsOneWidget);
    expect(find.byKey(const Key('provided-dashboard-hero')), findsOneWidget);
    expect(
      find.byKey(const Key('provided-daily-intelligence')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('provided-secondary-ai-coach')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('connected-health-test-card')), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-reference-calories-card')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('dashboard-calories-macros-horizontal')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('dashboard-reference-macros-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard-mobile-summary-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard-mobile-body-twin-snapshot')),
      findsOneWidget,
    );
    expect(find.text('Personal Health AI test panel'), findsOneWidget);
    expect(find.text('Today Summary test panel'), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-mobile-workout-library-card')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPad portrait keeps current sections and retired cards out', (
    tester,
  ) async {
    await setViewport(tester, width: 1024, height: 1366);
    await tester.pumpWidget(subject(platform: TargetPlatform.iOS));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-unified-adaptive-layout')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('provided-dashboard-hero')), findsOneWidget);
    expect(
      find.byKey(const Key('provided-daily-intelligence')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboard-ai-coach-slot')), findsOneWidget);
    expect(find.byKey(const Key('connected-health-test-card')), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-mobile-body-twin-snapshot')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard-mobile-workout-library-card')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large tablet landscape never revives the legacy dashboard', (
    tester,
  ) async {
    await setViewport(tester, width: 1366, height: 1024);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-reference-calories-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('provided-dashboard-hero')), findsOneWidget);
    expect(
      find.byKey(const Key('provided-daily-intelligence')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('provided-secondary-ai-coach')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard-mobile-body-twin-snapshot')),
      findsOneWidget,
    );
    expect(find.text('Personal Health AI test panel'), findsOneWidget);
    expect(find.text('Today Summary test panel'), findsOneWidget);
    final rail = tester.widget<ConstrainedBox>(
      find.byKey(const Key('dashboard-current-content-rail')),
    );
    expect(rail.constraints.maxWidth, 840);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone Health Hub follows the Edit visibility setting', (
    tester,
  ) async {
    await setViewport(tester, width: 390, height: 1200);
    await tester.pumpWidget(
      subject(visibleSections: const {DashboardSectionIds.aiCoach}),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-ai-coach-slot')), findsOneWidget);
    expect(find.byKey(const Key('connected-health-test-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI Coach visibility applies to both supplied coach surfaces', (
    tester,
  ) async {
    await setViewport(tester, width: 390, height: 1200);
    await tester.pumpWidget(
      subject(visibleSections: const {DashboardSectionIds.calories}),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-ai-coach-slot')), findsNothing);
    expect(
      find.byKey(const Key('dashboard-secondary-ai-coach-slot')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('dashboard-daily-intelligence-slot')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard-personal-health-ai-slot')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
