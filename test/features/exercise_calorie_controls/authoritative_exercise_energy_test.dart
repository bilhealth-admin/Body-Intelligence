import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/providers/exercise_calorie_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 8, 10, 12);

  ConnectedHealthSnapshot snapshot({required bool verified}) =>
      ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.synchronized,
        platformSource: 'Health Connect',
        availableSources: const ['Health Connect'],
        signals: [
          ConnectedHealthSignalView(
            key: 'activeEnergy',
            value: 321,
            unit: 'kcal',
            source: 'Health Connect',
            observedAt: day,
            confidence: .95,
          ),
        ],
        importedCount: 1,
        lastSyncAt: day,
        failureCode: null,
        deviceVerified: verified,
      );

  test('accepts active energy only from a verified native device', () {
    final energy = authoritativeExerciseEnergyForDay(
      snapshot(verified: true),
      day,
    );
    expect(energy?.kcal, 321);
    expect(energy?.source, 'Health Connect');
  });

  test('rejects simulator or unverified source evidence', () {
    expect(
      authoritativeExerciseEnergyForDay(snapshot(verified: false), day),
      isNull,
    );
  });
}
