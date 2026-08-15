import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_header.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_profile_required_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unprofiled dashboard keeps coach, honest metrics, and CTA', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardProfileRequiredCard(
              hero: const DashboardHeader(),
              message: 'Complete your profile',
              actionLabel: 'Complete profile',
              onAction: () => opened = true,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('dashboard-ai-coach-entry')), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-empty-calories-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboard-empty-steps-card')), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    await tester.tap(
      find.byKey(const Key('dashboard-complete-profile-action')),
    );
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unprofiled dashboard fits 320px at text scale 1.5', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: DashboardProfileRequiredCard(
                hero: const DashboardHeader(),
                message: 'Complete your profile to calculate targets.',
                actionLabel: 'Complete profile',
                onAction: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
