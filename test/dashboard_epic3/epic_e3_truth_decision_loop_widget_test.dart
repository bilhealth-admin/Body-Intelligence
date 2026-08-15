import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone exposes the trusted Body Twin without legacy feedback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var accepted = 0;
    var done = 0;
    var notSuitable = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PremiumDashboardBenchmark(
              arabic: false,
              actionTitle: 'Log today’s weight',
              actionReason: 'Comparable observations improve trend confidence.',
              actionEvidence: 'No weight check-in recorded today',
              confidence: 'Emerging',
              missingEvidence: 'A comparable weight observation is missing.',
              onAction: () {},
              onAccepted: () => accepted += 1,
              onDone: () => done += 1,
              onNotSuitable: () => notSuitable += 1,
              dailyIntelligence: const SizedBox(height: 80),
              personalHealthAi: const SizedBox.shrink(),
              bodyTwinSummary: 'A cautious direction is forming.',
              bodyTwinEvidence: 'Local observations only',
              nutritionSummary: 'Nutrition context',
              nutritionEvidence: 'Two meal records',
              trendSummary: 'Trend context',
              trendEvidence: 'Comparable observations',
              loggingItems: const [
                DashboardLoggingItem(label: 'Weight', recorded: false),
                DashboardLoggingItem(label: 'Meals', recorded: true),
                DashboardLoggingItem(label: 'Water', recorded: true),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-mobile-body-twin-snapshot')),
      findsOneWidget,
    );
    expect(find.text('A cautious direction is forming.'), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-truth-explanation-surface')),
      findsNothing,
    );
    expect(find.byKey(const Key('dashboard-truth-abstention')), findsNothing);
    expect(find.byKey(const Key('dashboard-decision-feedback')), findsNothing);
    expect(accepted, 0);
    expect(done, 0);
    expect(notSuitable, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abstention detail stays out of the compact dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PremiumDashboardBenchmark(
              arabic: true,
              actionTitle: 'حافظ على الخطة',
              actionReason: 'الأدلة الحالية لا تبرر تغيير الخطة.',
              actionEvidence: 'الملاحظات المحلية المتاحة',
              confidence: 'الأدلة غير كافية',
              missingEvidence: 'نحتاج قياسات قابلة للمقارنة.',
              abstentionReason: 'الأدلة الحالية لا تبرر تغيير الخطة.',
              onAction: null,
              onAccepted: () {},
              onDone: () {},
              onNotSuitable: () {},
              dailyIntelligence: const SizedBox(height: 80),
              personalHealthAi: const SizedBox.shrink(),
              bodyTwinSummary: 'ملخص',
              bodyTwinEvidence: 'دليل',
              nutritionSummary: 'تغذية',
              nutritionEvidence: 'دليل التغذية',
              trendSummary: 'اتجاه',
              trendEvidence: 'دليل الاتجاه',
              loggingItems: const [
                DashboardLoggingItem(label: 'الوزن', recorded: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-mobile-body-twin-snapshot')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboard-truth-abstention')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
