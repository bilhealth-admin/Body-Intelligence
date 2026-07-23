import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_pipeline.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_validation_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pipeline remains a thin composition of established AI boundaries', () {
    const composer = TruthRuleComposer();
    const decisionGate = TruthDecisionGate();
    const validationGate = TruthDecisionValidationGate();
    const pipeline = TruthDecisionPipeline(
      composer: composer,
      decisionGate: decisionGate,
      validationGate: validationGate,
    );

    expect(pipeline.composer, same(composer));
    expect(pipeline.decisionGate, same(decisionGate));
    expect(pipeline.validationGate, same(validationGate));
  });
}
