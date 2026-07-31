import '../domain/prompt_envelope.dart';

final class PromptEngineIntegrityValidator {
  const PromptEngineIntegrityValidator();

  List<String> validate(PromptEnvelope envelope) {
    final issues = <String>[];
    if (envelope.maximumOutputCharacters <= 0) {
      issues.add('maximum_output_characters_must_be_positive');
    }
    if (envelope.status == PromptEnvelopeStatus.ready) {
      if (envelope.systemInstruction.trim().isEmpty) {
        issues.add('ready_prompt_requires_system_instruction');
      }
      if (envelope.userInstruction.trim().isEmpty) {
        issues.add('ready_prompt_requires_user_instruction');
      }
      if (envelope.safetyRequirements.isEmpty) {
        issues.add('ready_prompt_requires_safety_requirements');
      }
    }
    if (envelope.status != PromptEnvelopeStatus.ready &&
        envelope.contextLines.isNotEmpty) {
      issues.add('non_ready_prompt_must_not_expose_context');
    }
    return issues..sort();
  }
}
