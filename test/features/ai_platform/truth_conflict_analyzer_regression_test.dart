import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_conflict_analyzer.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'conflict analysis does not alter Truth Engine assessment semantics',
    () {
      final signals = [
        _signal('support', TruthSignalDirection.supports, 0.8, 1),
        _signal('oppose', TruthSignalDirection.opposes, 0.2, 1),
      ];

      final before = const TruthEngine().assess(signals: signals);
      final conflict = const TruthConflictAnalyzer().analyze(signals: signals);
      final after = const TruthEngine().assess(signals: signals);

      expect(before.status, TruthAssessmentStatus.uncertain);
      expect(after.status, before.status);
      expect(after.score, before.score);
      expect(after.confidence, before.confidence);
      expect(conflict.hasConflict, isTrue);
    },
  );

  test('analyzer remains offline, clock-free, and caller-owned', () {
    final signals = <TruthSignal>[
      _signal('support', TruthSignalDirection.supports, 1, 1),
    ];

    final result = const TruthConflictAnalyzer().analyze(signals: signals);
    signals.clear();

    expect(result.supportingSignalKeys, ['support']);
    expect(result.status.name, 'none');
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
      description: 'Regression evidence for $key.',
      source: 'test',
    ),
  );
}
