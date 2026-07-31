import '../domain/scientific_validation.dart';

final class ScientificValidationIntegrityValidator {
  const ScientificValidationIntegrityValidator();

  List<String> validateRequest(ScientificValidationRequest request) {
    final issues = <String>[];
    if (request.sourceSummary.trim().isEmpty) {
      issues.add('Source summary is required.');
    }
    final ids = <String>{};
    for (final claim in request.claims) {
      if (claim.id.trim().isEmpty) {
        issues.add('Claim id is required.');
      } else if (!ids.add(claim.id)) {
        issues.add('Duplicate claim id: ${claim.id}.');
      }
      if (claim.statement.trim().isEmpty) {
        issues.add('Claim ${claim.id} has no statement.');
      }
      if (claim.confidence.isNaN ||
          claim.confidence < 0 ||
          claim.confidence > 1) {
        issues.add('Claim ${claim.id} has invalid confidence.');
      }
      if (claim.evidenceIds.isEmpty) {
        issues.add('Claim ${claim.id} has no evidence.');
      }
    }
    issues.sort();
    return List.unmodifiable(issues);
  }

  List<String> validateResult(ScientificValidationResult result) {
    final issues = <String>[];
    if (result.status == ScientificValidationStatus.validated &&
        result.records.isEmpty) {
      issues.add('Validated result must contain records.');
    }
    if (result.status != ScientificValidationStatus.validated &&
        result.records.isNotEmpty) {
      issues.add('Non-validated result must not expose records.');
    }
    if (result.status == ScientificValidationStatus.validated &&
        result.issues.isNotEmpty) {
      issues.add('Validated result must not contain issues.');
    }
    issues.sort();
    return List.unmodifiable(issues);
  }
}
