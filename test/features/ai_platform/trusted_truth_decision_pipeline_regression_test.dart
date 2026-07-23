import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_pipeline.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_pipeline_integrity_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/trusted_truth_decision_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trusted pipeline remains a thin composition of AI-013 and AI-014', () {
    const pipeline = TruthDecisionPipeline();
    const integrityGate = TruthDecisionPipelineIntegrityGate();
    const trusted = TrustedTruthDecisionPipeline(
      pipeline: pipeline,
      integrityGate: integrityGate,
    );

    expect(trusted.pipeline, same(pipeline));
    expect(trusted.integrityGate, same(integrityGate));
  });
}
