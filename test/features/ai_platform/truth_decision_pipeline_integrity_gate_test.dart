import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_pipeline_integrity_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_pipeline_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_pipeline.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_pipeline_integrity_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final proposition = TruthProposition<bool>(
    key: 'sleep.ready',
    description: 'Local sleep evidence supports recovery.',
  );
  final supported = TruthDecisionCandidate<String>(
    value: 'recover',
    label: 'Recover',
    summary: 'Prioritize recovery.',
    reasonWhenNotChosen: 'Truth evidence did not support recovery.',
  );
  final contradicted = TruthDecisionCandidate<String>(
    value: 'continue',
    label: 'Continue',
    summary: 'Continue the current plan.',
    reasonWhenNotChosen: 'Truth evidence did not contradict recovery.',
  );

  test('accepts the exact trusted pipeline result produced by AI-013', () {
    const pipeline = TruthDecisionPipeline();
    const gate = TruthDecisionPipelineIntegrityGate();
    final pipelineResult = pipeline.evaluate<bool, String>(
      proposition: proposition,
      context: true,
      rules: <TruthRule<bool>>[
        TruthRule<bool>(
          key: 'sleep.supported',
          propositionKey: proposition.key,
          direction: TruthSignalDirection.supports,
          strength: 1,
          reliability: 1,
          matches: (value) => value,
          evidence: (_) => AiEvidence(
            key: 'sleep.local',
            description: 'Local sleep observation.',
            source: 'truth_decision_pipeline_integrity_gate_test',
          ),
        ),
      ],
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    final result = gate.evaluate(pipelineResult);

    expect(result.canProceed, isTrue);
    expect(result.integrity.isValid, isTrue);
    expect(result.pipelineResult, same(pipelineResult));
  });

  test('rejects a pipeline envelope whose report provenance was replaced', () {
    const pipeline = TruthDecisionPipeline();
    const composer = TruthRuleComposer();
    const gate = TruthDecisionPipelineIntegrityGate();
    final valid = pipeline.evaluate<bool, String>(
      proposition: proposition,
      context: true,
      rules: <TruthRule<bool>>[
        TruthRule<bool>(
          key: 'sleep.supported',
          propositionKey: proposition.key,
          direction: TruthSignalDirection.supports,
          strength: 1,
          reliability: 1,
          matches: (value) => value,
          evidence: (_) => AiEvidence(
            key: 'sleep.local',
            description: 'Local sleep observation.',
            source: 'truth_decision_pipeline_integrity_gate_test',
          ),
        ),
      ],
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );
    final replacementReport = composer.report(
      proposition: proposition,
      context: true,
      rules: <TruthRule<bool>>[
        TruthRule<bool>(
          key: 'sleep.supported',
          propositionKey: proposition.key,
          direction: TruthSignalDirection.supports,
          strength: 1,
          reliability: 1,
          matches: (value) => value,
          evidence: (_) => AiEvidence(
            key: 'sleep.local',
            description: 'Local sleep observation.',
            source: 'truth_decision_pipeline_integrity_gate_test',
          ),
        ),
      ],
    );
    final forged = TruthDecisionPipelineResult<String>(
      report: replacementReport,
      validation: valid.validation,
    );

    final result = gate.evaluate(forged);

    expect(result.isRejected, isTrue);
    expect(
      result.integrity.issues.map((issue) => issue.code),
      contains(TruthDecisionPipelineIntegrityIssueCode.reportReferenceMismatch),
    );
  });
}
