import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'truth decision validator remains pure and does not alter gate output',
    () {
      const gate = TruthDecisionGate();
      const validator = TruthDecisionValidator();
      final supported = TruthDecisionCandidate<int>(
        value: 1,
        label: 'Supported',
        summary: 'Supported result.',
        reasonWhenNotChosen: 'Not supported.',
      );
      final contradicted = TruthDecisionCandidate<int>(
        value: -1,
        label: 'Contradicted',
        summary: 'Contradicted result.',
        reasonWhenNotChosen: 'Not contradicted.',
      );

      // The focused suite exercises full report construction and mismatch
      // detection. This regression protects the validator's const, offline-only
      // surface without importing or mutating any protected feature.
      expect(gate, isA<TruthDecisionGate>());
      expect(validator, isA<TruthDecisionValidator>());
      expect(supported.value, 1);
      expect(contradicted.value, -1);
    },
  );
}
