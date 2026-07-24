import '../domain/ai_coach_response.dart';
import '../domain/prompt_engine_policy.dart';
import '../domain/prompt_envelope.dart';
import 'prompt_engine_integrity_validator.dart';

/// Provider-neutral deterministic prompt boundary.
///
/// It projects only trusted repository-owned coaching output into a bounded
/// envelope. It performs no network call and does not treat an LLM as a source
/// of truth.
final class PromptEngine {
  const PromptEngine({
    this.policy = const PromptEnginePolicy(),
    this.integrityValidator = const PromptEngineIntegrityValidator(),
  });

  final PromptEnginePolicy policy;
  final PromptEngineIntegrityValidator integrityValidator;

  PromptEnvelope build({
    required DateTime generatedAt,
    required AiCoachResponse coachResponse,
  }) {
    if (!coachResponse.canProceed) {
      return _validated(
        PromptEnvelope(
          status: coachResponse.status == AiCoachStatus.rejected
              ? PromptEnvelopeStatus.rejected
              : PromptEnvelopeStatus.abstained,
          generatedAt: generatedAt,
          systemInstruction: '',
          userInstruction: '',
          contextLines: const [],
          evidenceIds: const [],
          safetyRequirements: coachResponse.safetyNotes,
          maximumOutputCharacters: policy.maximumOutputCharacters,
        ),
      );
    }

    final candidates = <String>[
      'Headline: ${coachResponse.headline.trim()}',
      'Coach message: ${coachResponse.message.trim()}',
      ...coachResponse.uncertaintyNotes.map((value) => 'Uncertainty: $value'),
    ];
    final context = <String>[];
    var usedCharacters = 0;
    for (final candidate in candidates) {
      if (context.length >= policy.maximumContextLines) {
        break;
      }
      final normalized = candidate.trim();
      if (normalized.isEmpty) {
        continue;
      }
      final additional = normalized.length + (context.isEmpty ? 0 : 1);
      if (usedCharacters + additional > policy.maximumContextCharacters) {
        break;
      }
      context.add(normalized);
      usedCharacters += additional;
    }

    return _validated(
      PromptEnvelope(
        status: PromptEnvelopeStatus.ready,
        generatedAt: generatedAt,
        systemInstruction:
            'Use only the supplied BIL context. Preserve uncertainty and safety limits. Do not invent measurements, diagnoses, evidence, or actions.',
        userInstruction:
            'Rewrite the approved BIL coaching response clearly without changing its decision, evidence, or safety meaning.',
        contextLines: context,
        evidenceIds: coachResponse.evidenceIds,
        safetyRequirements: <String>{
          'Do not introduce new health claims.',
          'Do not change or add an action.',
          'Preserve all uncertainty and safety constraints.',
          ...coachResponse.safetyNotes,
        },
        maximumOutputCharacters: policy.maximumOutputCharacters,
      ),
    );
  }

  PromptEnvelope _validated(PromptEnvelope envelope) {
    final issues = integrityValidator.validate(envelope);
    if (issues.isEmpty) {
      return envelope;
    }
    return PromptEnvelope(
      status: PromptEnvelopeStatus.rejected,
      generatedAt: envelope.generatedAt,
      systemInstruction: '',
      userInstruction: '',
      contextLines: const [],
      evidenceIds: const [],
      safetyRequirements: issues,
      maximumOutputCharacters: policy.maximumOutputCharacters,
    );
  }
}
