import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AiEvidence evidence(String key) => AiEvidence(
    key: key,
    description: 'Deterministic evidence for $key',
    source: 'test-engine',
  );

  TruthSignal signal({
    required String key,
    required TruthSignalDirection direction,
    required double strength,
    required double reliability,
  }) => TruthSignal(
    key: key,
    direction: direction,
    strength: strength,
    reliability: reliability,
    evidence: evidence(key),
  );

  test('supporting signals produce a supported explainable assessment', () {
    const engine = TruthEngine();

    final result = engine.assess(
      signals: [
        signal(
          key: 'a',
          direction: TruthSignalDirection.supports,
          strength: 0.8,
          reliability: 1,
        ),
        signal(
          key: 'b',
          direction: TruthSignalDirection.supports,
          strength: 0.6,
          reliability: 0.8,
        ),
      ],
    );

    expect(result.status, TruthAssessmentStatus.supported);
    expect(result.score, closeTo(0.711, 0.001));
    expect(result.confidence, closeTo(0.9, 0.001));
    expect(result.evidence.map((item) => item.key), ['a', 'b']);
    expect(result.rationale, contains('normalized score='));
  });

  test('opposing evidence can produce a contradicted assessment', () {
    const engine = TruthEngine();

    final result = engine.assess(
      signals: [
        signal(
          key: 'opposes',
          direction: TruthSignalDirection.opposes,
          strength: 0.9,
          reliability: 1,
        ),
      ],
    );

    expect(result.status, TruthAssessmentStatus.contradicted);
    expect(result.score, -0.9);
  });

  test('empty input safely reports insufficient evidence', () {
    const engine = TruthEngine();

    final result = engine.assess(
      signals: const [],
      missingEvidence: const ['weight trend'],
    );

    expect(result.status, TruthAssessmentStatus.insufficientEvidence);
    expect(result.score, 0);
    expect(result.confidence, 0);
    expect(result.missingEvidence, ['weight trend']);
  });

  test('result is deterministic regardless of signal input order', () {
    const engine = TruthEngine();
    final first = signal(
      key: 'a',
      direction: TruthSignalDirection.supports,
      strength: 0.7,
      reliability: 0.9,
    );
    final second = signal(
      key: 'b',
      direction: TruthSignalDirection.opposes,
      strength: 0.2,
      reliability: 0.8,
    );

    final left = engine.assess(signals: [first, second]);
    final right = engine.assess(signals: [second, first]);

    expect(right.status, left.status);
    expect(right.score, left.score);
    expect(right.confidence, left.confidence);
    expect(right.rationale, left.rationale);
    expect(
      right.evidence.map((item) => item.key),
      left.evidence.map((item) => item.key),
    );
  });

  test('duplicate signal keys are rejected', () {
    const engine = TruthEngine();
    final duplicate = signal(
      key: 'same',
      direction: TruthSignalDirection.supports,
      strength: 0.5,
      reliability: 1,
    );

    expect(
      () => engine.assess(signals: [duplicate, duplicate]),
      throwsArgumentError,
    );
  });

  test('signal ranges are validated', () {
    expect(
      () => TruthSignal(
        key: 'invalid',
        direction: TruthSignalDirection.supports,
        strength: 1.1,
        reliability: 1,
        evidence: evidence('invalid'),
      ),
      throwsRangeError,
    );
  });
}
