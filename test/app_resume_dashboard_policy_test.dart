import 'package:body_intelligence_log/app/services/app_resume_dashboard_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only a background interval at the threshold is meaningful', () {
    var now = DateTime(2026, 9, 8, 10);
    final policy = MeaningfulResumePolicy(now: () => now);

    expect(policy.handle(AppLifecycleState.paused), isFalse);
    now = now.add(const Duration(minutes: 29, seconds: 59));
    expect(policy.handle(AppLifecycleState.resumed), isFalse);

    expect(policy.handle(AppLifecycleState.hidden), isFalse);
    now = now.add(const Duration(minutes: 30));
    expect(policy.handle(AppLifecycleState.resumed), isTrue);
    expect(policy.handle(AppLifecycleState.resumed), isFalse);
  });

  test('inactive and duplicate background events preserve the right clock', () {
    var now = DateTime(2026, 9, 8, 10);
    final policy = MeaningfulResumePolicy(now: () => now);

    expect(policy.handle(AppLifecycleState.inactive), isFalse);
    now = now.add(const Duration(hours: 1));
    expect(policy.handle(AppLifecycleState.resumed), isFalse);

    expect(policy.handle(AppLifecycleState.hidden), isFalse);
    now = now.add(const Duration(minutes: 20));
    expect(policy.handle(AppLifecycleState.paused), isFalse);
    now = now.add(const Duration(minutes: 10));
    expect(policy.handle(AppLifecycleState.resumed), isTrue);
  });

  testWidgets(
    'coordinator invokes its callback once after a meaningful return',
    (tester) async {
      var now = DateTime(2026, 9, 8, 10);
      var returns = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AppResumeDashboardCoordinator(
            now: () => now,
            onMeaningfulResume: () => returns++,
            child: const Text('in-progress input'),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(returns, 1);
      expect(find.text('in-progress input'), findsOneWidget);
    },
  );
}
