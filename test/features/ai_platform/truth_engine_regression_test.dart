import 'dart:io';

import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/explainable_ai_decision.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI-001 explainable decision contract remains compatible', () {
    final evidence = AiEvidence(
      key: 'truth-result',
      description: 'A deterministic Truth Engine result.',
      source: 'TruthEngine',
    );

    final decision = ExplainableAiDecision<String>.action(
      value: 'observe',
      summary: 'Observe the current signal.',
      rationale: 'The deterministic evidence supports observation.',
      evidence: [evidence],
      confidence: AiConfidenceLevel.medium,
    );

    expect(decision.hasAction, isTrue);
    expect(decision.evidence.single, same(evidence));
  });

  test('Truth Engine remains provider-neutral and offline-only', () {
    final files = [
      File('lib/features/ai_platform/domain/truth_signal.dart'),
      File('lib/features/ai_platform/domain/truth_assessment.dart'),
      File('lib/features/ai_platform/services/truth_engine.dart'),
    ];

    const forbidden = [
      'dart:io',
      'dart:html',
      'package:http',
      'firebase',
      'openai',
      'anthropic',
      'gemini',
      'DateTime.now',
      'Random(',
    ];

    for (final file in files) {
      final source = file.readAsStringSync().toLowerCase();
      for (final token in forbidden) {
        expect(source, isNot(contains(token.toLowerCase())), reason: file.path);
      }
    }
  });

  test('Truth assessment evidence is immutable', () {
    const engine = TruthEngine();
    final result = engine.assess(
      signals: [
        TruthSignal(
          key: 'stable',
          direction: TruthSignalDirection.supports,
          strength: 0.8,
          reliability: 1,
          evidence: AiEvidence(
            key: 'stable',
            description: 'Stable evidence',
            source: 'test',
          ),
        ),
      ],
    );

    expect(
      () => result.evidence.add(
        AiEvidence(key: 'x', description: 'x', source: 'x'),
      ),
      throwsUnsupportedError,
    );
    expect(result.status, TruthAssessmentStatus.supported);
  });
}
