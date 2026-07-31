import '../domain/proprietary_bil_intelligence.dart';

final class ProprietaryBilIntelligenceIntegrityValidator {
  const ProprietaryBilIntelligenceIntegrityValidator();

  List<String> validateRequest(ProprietaryBilIntelligenceRequest request) {
    final issues = <String>[];
    final ids = <String>{};
    for (final signal in request.signals) {
      if (signal.id.trim().isEmpty) {
        issues.add('signal id must not be blank.');
      }
      if (!ids.add(signal.id)) {
        issues.add('signal ids must be unique.');
      }
      if (signal.statement.trim().isEmpty) {
        issues.add('signal statement must not be blank.');
      }
      if (signal.confidence < 0 || signal.confidence > 1) {
        issues.add('signal confidence must be between 0 and 1.');
      }
      if (signal.evidenceIds.isEmpty ||
          signal.evidenceIds.any((value) => value.trim().isEmpty)) {
        issues.add('every signal must preserve non-blank evidence.');
      }
    }
    if (request.requiredSignalIds.any((value) => value.trim().isEmpty)) {
      issues.add('required signal ids must not be blank.');
    }
    return List.unmodifiable(issues);
  }

  List<String> validateResult(ProprietaryBilIntelligenceResult result) {
    final issues = <String>[];
    if (result.canProceed && result.summary.trim().isEmpty) {
      issues.add('approved intelligence must include a summary.');
    }
    if (result.canProceed && result.evidenceIds.isEmpty) {
      issues.add('approved intelligence must preserve evidence.');
    }
    if (!result.canProceed && result.issues.isEmpty) {
      issues.add(
        'non-approved intelligence must explain abstention or rejection.',
      );
    }
    return List.unmodifiable(issues);
  }
}
