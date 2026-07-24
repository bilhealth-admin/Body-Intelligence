enum ScientificValidationStatus { validated, abstained, rejected }

enum ScientificClaimStrength { observed, supportedInference, forecast }

final class ScientificClaim {
  ScientificClaim({
    required this.id,
    required this.statement,
    required this.strength,
    required this.confidence,
    required Iterable<String> evidenceIds,
    required Iterable<String> assumptions,
  }) : evidenceIds = List.unmodifiable(evidenceIds),
       assumptions = List.unmodifiable(assumptions);

  final String id;
  final String statement;
  final ScientificClaimStrength strength;
  final double confidence;
  final List<String> evidenceIds;
  final List<String> assumptions;
}

final class ScientificValidationRequest {
  ScientificValidationRequest({
    required DateTime generatedAt,
    required this.sourceSummary,
    required Iterable<ScientificClaim> claims,
    required Iterable<String> availableEvidenceIds,
  }) : generatedAt = generatedAt.toUtc(),
       claims = List.unmodifiable(claims),
       availableEvidenceIds = List.unmodifiable(availableEvidenceIds);

  final DateTime generatedAt;
  final String sourceSummary;
  final List<ScientificClaim> claims;
  final List<String> availableEvidenceIds;
}

final class ScientificValidationRecord {
  ScientificValidationRecord({
    required this.claimId,
    required this.reproducibleStatement,
    required this.strength,
    required this.confidence,
    required Iterable<String> evidenceIds,
    required Iterable<String> assumptions,
    required Iterable<String> uncertaintyDisclosures,
  }) : evidenceIds = List.unmodifiable(evidenceIds),
       assumptions = List.unmodifiable(assumptions),
       uncertaintyDisclosures = List.unmodifiable(uncertaintyDisclosures);

  final String claimId;
  final String reproducibleStatement;
  final ScientificClaimStrength strength;
  final double confidence;
  final List<String> evidenceIds;
  final List<String> assumptions;
  final List<String> uncertaintyDisclosures;
}

final class ScientificValidationResult {
  ScientificValidationResult({
    required this.status,
    required DateTime generatedAt,
    required Iterable<ScientificValidationRecord> records,
    required Iterable<String> issues,
  }) : generatedAt = generatedAt.toUtc(),
       records = List.unmodifiable(records),
       issues = List.unmodifiable(issues);

  final ScientificValidationStatus status;
  final DateTime generatedAt;
  final List<ScientificValidationRecord> records;
  final List<String> issues;

  bool get canProceed => status == ScientificValidationStatus.validated;
}
