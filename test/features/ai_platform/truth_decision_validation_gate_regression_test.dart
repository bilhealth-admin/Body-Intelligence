import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_validation_gate_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_validation_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'validation gate remains a thin projection over the existing validator',
    () {
      const validator = TruthDecisionValidator();
      const gate = TruthDecisionValidationGate(validator: validator);

      expect(gate.validator, same(validator));
      expect(gate, isA<TruthDecisionValidationGate>());
      expect(
        TruthDecisionValidationGateStatus.values,
        containsAll(<TruthDecisionValidationGateStatus>[
          TruthDecisionValidationGateStatus.accepted,
          TruthDecisionValidationGateStatus.rejected,
        ]),
      );
    },
  );
}
