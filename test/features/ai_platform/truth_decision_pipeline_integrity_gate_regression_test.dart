import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_pipeline_integrity_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_pipeline_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI-014 remains a thin validator and gate over AI-013 output', () {
    const validator = TruthDecisionPipelineValidator();
    const gate = TruthDecisionPipelineIntegrityGate(validator: validator);

    expect(gate.validator, same(validator));
  });
}
