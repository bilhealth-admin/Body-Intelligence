import '../domain/scientific_validation.dart';
import '../domain/scientific_validation_policy.dart';
import 'scientific_validation_integrity_validator.dart';

/// Deterministic scientific validation and explainability boundary.
///
/// The engine validates caller-supplied claims against explicit evidence,
/// preserves assumptions, discloses uncertainty, and abstains rather than
/// inventing support. It performs no provider, network, or clinical action.
final class ScientificValidationEngine {
  const ScientificValidationEngine({
    this.policy = const ScientificValidationPolicy(),
    this.integrityValidator = const ScientificValidationIntegrityValidator(),
  });

  final ScientificValidationPolicy policy;
  final ScientificValidationIntegrityValidator integrityValidator;

  ScientificValidationResult validate(ScientificValidationRequest request) {
    final requestIssues = integrityValidator.validateRequest(request);
    if (requestIssues.isNotEmpty) {
      return _validated(
        ScientificValidationResult(
          status: ScientificValidationStatus.rejected,
          generatedAt: request.generatedAt,
          records: const [],
          issues: requestIssues,
        ),
      );
    }

    if (request.claims.length > policy.maximumClaims) {
      return _abstain(request, 'Claim limit exceeded.');
    }

    final evidence = request.availableEvidenceIds.toSet();
    final records = <ScientificValidationRecord>[];
    final unsupported = <String>[];

    final claims = request.claims.toList(growable: false)
      ..sort((left, right) => left.id.compareTo(right.id));
    for (final claim in claims) {
      final missingEvidence =
          claim.evidenceIds
              .where((id) => !evidence.contains(id))
              .toList(growable: false)
            ..sort();
      if (missingEvidence.isNotEmpty ||
          claim.confidence < policy.minimumConfidence ||
          claim.statement.length > policy.maximumStatementCharacters) {
        unsupported.add(claim.id);
        continue;
      }

      final uncertainty = <String>[];
      if (claim.strength != ScientificClaimStrength.observed) {
        uncertainty.add('Claim is not a direct observation.');
      }
      if (claim.assumptions.isNotEmpty) {
        uncertainty.add('Claim depends on explicit assumptions.');
      }
      if (claim.confidence < 1) {
        uncertainty.add('Claim confidence is below certainty.');
      }

      records.add(
        ScientificValidationRecord(
          claimId: claim.id,
          reproducibleStatement: claim.statement.trim(),
          strength: claim.strength,
          confidence: claim.confidence,
          evidenceIds: claim.evidenceIds.toSet().toList(growable: false)
            ..sort(),
          assumptions: claim.assumptions,
          uncertaintyDisclosures: uncertainty,
        ),
      );
    }

    if (unsupported.isNotEmpty) {
      unsupported.sort();
      return _abstain(
        request,
        'Unsupported claims: ${unsupported.join(', ')}.',
      );
    }
    if (records.isEmpty) {
      return _abstain(request, 'No reproducible claims were supplied.');
    }

    return _validated(
      ScientificValidationResult(
        status: ScientificValidationStatus.validated,
        generatedAt: request.generatedAt,
        records: records,
        issues: const [],
      ),
    );
  }

  ScientificValidationResult _abstain(
    ScientificValidationRequest request,
    String issue,
  ) {
    return _validated(
      ScientificValidationResult(
        status: ScientificValidationStatus.abstained,
        generatedAt: request.generatedAt,
        records: const [],
        issues: [issue],
      ),
    );
  }

  ScientificValidationResult _validated(ScientificValidationResult result) {
    final issues = integrityValidator.validateResult(result);
    if (issues.isEmpty) {
      return result;
    }
    return ScientificValidationResult(
      status: ScientificValidationStatus.rejected,
      generatedAt: result.generatedAt,
      records: const [],
      issues: issues,
    );
  }
}
