import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_conflict_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_conflict_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = TruthConflictAnalyzer();

  test('reports no conflict when signals point in one direction', () {
    final result = analyzer.analyze(
      signals: [
        _signal('support.a', TruthSignalDirection.supports, 0.8, 1),
        _signal('support.b', TruthSignalDirection.supports, 0.4, 0.5),
      ],
    );

    expect(result.status, TruthConflictStatus.none);
    expect(result.hasConflict, isFalse);
    expect(result.supportingSignalKeys, ['support.a', 'support.b']);
    expect(result.opposingSignalKeys, isEmpty);
    expect(result.supportWeight, closeTo(1.0, 0.0001));
  });

  test('explains support-dominant and opposition-dominant conflicts', () {
    final supportDominant = analyzer.analyze(
      signals: [
        _signal('support', TruthSignalDirection.supports, 0.9, 1),
        _signal('oppose', TruthSignalDirection.opposes, 0.2, 1),
      ],
    );
    final oppositionDominant = analyzer.analyze(
      signals: [
        _signal('support', TruthSignalDirection.supports, 0.2, 1),
        _signal('oppose', TruthSignalDirection.opposes, 0.9, 1),
      ],
    );

    expect(supportDominant.status, TruthConflictStatus.supportDominant);
    expect(oppositionDominant.status, TruthConflictStatus.oppositionDominant);
    expect(supportDominant.hasConflict, isTrue);
    expect(supportDominant.rationale, contains('absolute margin='));
  });

  test('uses normalized tolerance for balanced disagreement', () {
    final result = analyzer.analyze(
      signals: [
        _signal('support', TruthSignalDirection.supports, 0.8, 1),
        _signal('oppose', TruthSignalDirection.opposes, 0.76, 1),
      ],
    );

    expect(result.status, TruthConflictStatus.balanced);
    expect(result.margin, closeTo(0.04, 0.0001));
  });

  test('output is deterministic and immutable', () {
    final first = _signal('support', TruthSignalDirection.supports, 0.7, 0.8);
    final second = _signal('oppose', TruthSignalDirection.opposes, 0.3, 0.9);

    final left = analyzer.analyze(signals: [first, second]);
    final right = analyzer.analyze(signals: [second, first]);

    expect(right.status, left.status);
    expect(right.supportWeight, left.supportWeight);
    expect(right.oppositionWeight, left.oppositionWeight);
    expect(right.rationale, left.rationale);
    expect(
      () => right.supportingSignalKeys.add('other'),
      throwsUnsupportedError,
    );
  });

  test('duplicate signal keys are rejected', () {
    final duplicate = _signal('same', TruthSignalDirection.supports, 0.5, 1);

    expect(
      () => analyzer.analyze(signals: [duplicate, duplicate]),
      throwsArgumentError,
    );
  });
}

TruthSignal _signal(
  String key,
  TruthSignalDirection direction,
  double strength,
  double reliability,
) {
  return TruthSignal(
    key: key,
    direction: direction,
    strength: strength,
    reliability: reliability,
    evidence: AiEvidence(
      key: 'evidence.$key',
      description: 'Deterministic evidence for $key.',
      source: 'test',
    ),
  );
}
