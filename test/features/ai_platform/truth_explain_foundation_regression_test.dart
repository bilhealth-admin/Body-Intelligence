import 'package:body_intelligence_log/features/ai_platform/services/trusted_truth_decision_pipeline.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_explain_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public foundation remains a thin wrapper over AI-015', () {
    const pipeline = TrustedTruthDecisionPipeline();
    const foundation = TruthExplainFoundation(pipeline: pipeline);

    expect(foundation.pipeline, same(pipeline));
  });
}
