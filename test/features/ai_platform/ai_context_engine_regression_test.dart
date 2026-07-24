import 'package:body_intelligence_log/features/ai_platform/domain/ai_context.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_explain_foundation_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_context_integrity_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('context collections are immutable and provenance order is stable', () {
    final context = AiContext<String>(
      asOf: DateTime.utc(2026, 7, 24),
      truthStatus: TruthExplainFoundationStatus.abstention,
      truthDecision: null,
      bodySnapshot: null,
      bodyTrends: null,
      decisionHistory: const [],
      missingContextKeys: const ['truth.decision', 'body.snapshot'],
      provenance: <AiContextProvenance>[
        AiContextProvenance(
          contextKey: 'z',
          source: AiContextSource.bodyTwin,
          evidenceIds: const ['2', '1'],
        ),
        AiContextProvenance(
          contextKey: 'a',
          source: AiContextSource.truthExplain,
          evidenceIds: const ['1'],
        ),
      ],
    );

    expect(context.provenance.map((item) => item.contextKey), ['a', 'z']);
    expect(context.missingContextKeys, ['body.snapshot', 'truth.decision']);
    expect(() => context.missingContextKeys.add('x'), throwsUnsupportedError);
    expect(const AiContextIntegrityValidator().validate(context), isEmpty);
  });
}
