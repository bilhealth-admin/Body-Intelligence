import 'package:body_intelligence_log/engine/progress_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sparse weight data refuses direction and projection', () {
    final result = ProgressAnalysis.evaluate(
      samples: [
        ProgressSample(date: DateTime(2026, 7, 1), weightKg: 80),
        ProgressSample(date: DateTime(2026, 7, 2), weightKg: 79),
      ],
      goalWeightKg: 70,
    );
    expect(result.confidence, ProgressConfidence.insufficient);
    expect(result.weeklyDirectionKg, isNull);
    expect(result.projectedGoalDate, isNull);
  });

  test('dated regression reports cautious weekly and monthly direction', () {
    final result = ProgressAnalysis.evaluate(
      samples: List.generate(
        14,
        (index) => ProgressSample(
          date: DateTime(2026, 6, 1).add(Duration(days: index * 2)),
          weightKg: 80 - index * 0.1,
        ),
      ),
      goalWeightKg: 75,
      now: DateTime(2026, 7, 1),
    );
    expect(result.confidence, ProgressConfidence.high);
    expect(result.weeklyDirectionKg, closeTo(-0.35, 0.01));
    expect(result.monthlyDirectionKg, closeTo(-1.5, 0.05));
    expect(result.variabilityKg, lessThan(0.01));
    expect(result.projectedGoalDate, isNotNull);
  });
}
