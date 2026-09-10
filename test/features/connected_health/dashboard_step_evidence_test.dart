import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_step_trend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 10, 14);
  final today = DateTime(2026, 9, 10);
  ConnectedHealthSnapshot snapshot({
    bool verified = true,
    double value = 8000,
    DateTime? day,
  }) => const ConnectedHealthSnapshot.unavailable().copyWith(
    status: ConnectedHealthStatus.synchronized,
    platformSource: 'Apple Health',
    deviceVerified: verified,
    stepHistory: [
      ConnectedHealthSignalView(
        key: 'steps',
        value: value,
        unit: 'count',
        source: 'healthkit.statistics',
        observedAt: day ?? today.subtract(const Duration(days: 1)),
        confidence: 1,
      ),
    ],
  );

  test('new user with no records has no bars and no invented zero', () {
    final trend = DashboardStepTrend.fromEvidence(
      now: now,
      connected: null,
      localReadings: const [],
    );
    expect(trend.values, isEmpty);
    expect(trend.today, isNull);
    expect(trend.source, isNull);
  });

  test('last 30 records cannot masquerade as last 30 days', () {
    final trend = DashboardStepTrend.fromEvidence(
      now: now,
      connected: null,
      localReadings: [
        (day: today.subtract(const Duration(days: 60)), steps: 9000),
        (day: today.add(const Duration(days: 1)), steps: 9000),
        (day: today, steps: double.nan),
        (day: today, steps: -100),
      ],
    );
    expect(trend.values, isEmpty);
    expect(trend.today, isNull);
  });

  test('unverified preview health cache cannot produce production bars', () {
    final trend = DashboardStepTrend.fromEvidence(
      now: now,
      connected: snapshot(verified: false),
      localReadings: const [],
    );
    expect(trend.values, isEmpty);
    expect(trend.today, isNull);
  });

  test('real historical Health data does not invent a reading for today', () {
    final trend = DashboardStepTrend.fromEvidence(
      now: now,
      connected: snapshot(),
      localReadings: const [],
    );
    expect(trend.values.length, 30);
    expect(trend.values[28], 8000);
    expect(trend.values.last, 0);
    expect(trend.today, isNull);
    expect(trend.source, 'Apple Health');
  });

  test('a measured zero wins over a stale nonzero local fallback', () {
    final trend = DashboardStepTrend.fromEvidence(
      now: now,
      connected: snapshot(value: 0, day: today),
      localReadings: [(day: today, steps: 9000)],
    );
    expect(trend.values.every((value) => value == 0), isTrue);
    expect(trend.today, 0);
    expect(trend.source, 'Apple Health');
  });

  test('local records retain their actual dates and explicit source', () {
    final trend = DashboardStepTrend.fromEvidence(
      now: now,
      connected: null,
      localReadings: [
        (day: today, steps: 1234),
        (day: today.subtract(const Duration(days: 3)), steps: 50),
      ],
    );
    expect(trend.values.length, 30);
    expect(trend.values[26], 50);
    expect(trend.values[27], 0);
    expect(trend.values[28], 0);
    expect(trend.values.last, 1234);
    expect(trend.today, 1234);
    expect(trend.source, 'BIL');
  });

  test('steps bar heights are proportional to actual counts from zero', () {
    expect(dashboardStepBarFractions([10, 100, 1000]), [.01, .1, 1]);
    expect(dashboardStepBarFractions([0, -1, double.nan, double.infinity]), [
      0,
      0,
      0,
      0,
    ]);
    expect(dashboardStepBarFractions([]), isEmpty);
    expect(dashboardStepBarFractions([25, 25]), [1, 1]);
  });
}
