import 'package:body_intelligence_log/features/dashboard/domain/dashboard_trusted_body_twin_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final asOf = DateTime.utc(2026, 7, 31, 12);
  const adapter = DashboardTrustedBodyTwinAdapter();

  DashboardBodyTwinWeightObservation weight({
    required double kg,
    required DateTime at,
  }) => DashboardBodyTwinWeightObservation(
    kg: kg,
    observedAt: at,
    source: 'sameConditions',
  );

  test('exposes a fresh and consistent local weight', () {
    final result = adapter.build(
      asOf: asOf,
      weights: [weight(kg: 93.4, at: asOf.subtract(const Duration(hours: 4)))],
    );

    expect(result.status, DashboardBodyTwinTrustStatus.trusted);
    expect(result.canExposeBodyTwin, isTrue);
    expect(result.weightKg, 93.4);
    expect(result.engineVersion, 'dashboard-body-twin-trust-v1');
    expect(result.source, contains('sameConditions'));
  });

  test('blocks stale local weight', () {
    final result = adapter.build(
      asOf: asOf,
      weights: [weight(kg: 93.4, at: asOf.subtract(const Duration(days: 4)))],
    );

    expect(result.status, DashboardBodyTwinTrustStatus.stale);
    expect(result.canExposeBodyTwin, isFalse);
    expect(result.reasons.single, contains('older than 3 days'));
  });

  test('blocks inconsistent weight instead of repairing it', () {
    final result = adapter.build(
      asOf: asOf,
      weights: [weight(kg: 500, at: asOf.subtract(const Duration(hours: 1)))],
    );

    expect(result.status, DashboardBodyTwinTrustStatus.inconsistent);
    expect(result.canExposeBodyTwin, isFalse);
    expect(result.weightKg, 500);
  });

  test('keeps missing weight explicit', () {
    final result = adapter.build(asOf: asOf, weights: const []);

    expect(result.status, DashboardBodyTwinTrustStatus.unavailable);
    expect(result.canExposeBodyTwin, isFalse);
    expect(result.weightKg, isNull);
  });
}
