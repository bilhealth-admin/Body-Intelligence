import 'package:body_intelligence_log/engine/nutrient_evidence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known zero remains a complete measured total', () {
    final report = NutrientEvidenceEngine.total(const [
      NutrientObservation(value: 0, available: true),
      NutrientObservation(value: 0, available: true),
    ]);
    expect(report.state, NutrientEvidenceState.complete);
    expect(report.total, 0);
  });

  test('no known values reports unavailable rather than zero', () {
    final report = NutrientEvidenceEngine.total(const [
      NutrientObservation(value: 0, available: false),
    ]);
    expect(report.state, NutrientEvidenceState.unavailable);
    expect(report.total, isNull);
  });

  test('mixed evidence totals only known values and reports partial', () {
    final report = NutrientEvidenceEngine.total(const [
      NutrientObservation(value: 120, available: true),
      NutrientObservation(value: 0, available: false),
    ]);
    expect(report.state, NutrientEvidenceState.partial);
    expect(report.total, 120);
  });
}
