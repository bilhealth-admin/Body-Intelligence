import '../domain/proprietary_bil_intelligence.dart';
import '../domain/proprietary_bil_intelligence_policy.dart';
import 'proprietary_bil_intelligence_integrity_validator.dart';

/// Deterministic synthesis over trusted local engine outputs.
///
/// The engine never invents evidence, invokes a provider, or replaces the
/// truth-owned upstream engines. Unsupported or incomplete inputs abstain.
final class ProprietaryBilIntelligenceEngine {
  const ProprietaryBilIntelligenceEngine({
    this.policy = const ProprietaryBilIntelligencePolicy(),
    this.integrityValidator =
        const ProprietaryBilIntelligenceIntegrityValidator(),
  });

  final ProprietaryBilIntelligencePolicy policy;
  final ProprietaryBilIntelligenceIntegrityValidator integrityValidator;

  ProprietaryBilIntelligenceResult synthesize(
    ProprietaryBilIntelligenceRequest request,
  ) {
    final requestIssues = integrityValidator.validateRequest(request);
    if (requestIssues.isNotEmpty) {
      return _validated(
        ProprietaryBilIntelligenceResult(
          status: BilIntelligenceStatus.rejected,
          generatedAt: request.generatedAt,
          summary: '',
          signalIds: const [],
          evidenceIds: const [],
          issues: requestIssues,
        ),
      );
    }

    if (request.signals.length > policy.maximumSignals) {
      return _abstain(request, 'Signal limit exceeded.');
    }

    final byId = <String, BilIntelligenceSignal>{
      for (final signal in request.signals) signal.id: signal,
    };
    final missing =
        request.requiredSignalIds
            .where((id) => !byId.containsKey(id))
            .toList(growable: false)
          ..sort();
    if (missing.isNotEmpty) {
      return _abstain(
        request,
        'Missing required signals: ${missing.join(', ')}.',
      );
    }

    final accepted =
        request.signals
            .where(
              (signal) => signal.confidence >= policy.minimumSignalConfidence,
            )
            .toList(growable: false)
          ..sort((left, right) {
            final kind = left.kind.index.compareTo(right.kind.index);
            return kind != 0 ? kind : left.id.compareTo(right.id);
          });
    if (accepted.isEmpty) {
      return _abstain(request, 'No signal met the confidence threshold.');
    }

    final summary = accepted.map((signal) => signal.statement.trim()).join(' ');
    if (summary.length > policy.maximumSummaryCharacters) {
      return _abstain(
        request,
        'Synthesized summary exceeds the bounded output limit.',
      );
    }

    final evidence =
        accepted
            .expand((signal) => signal.evidenceIds)
            .toSet()
            .toList(growable: false)
          ..sort();

    return _validated(
      ProprietaryBilIntelligenceResult(
        status: BilIntelligenceStatus.approved,
        generatedAt: request.generatedAt,
        summary: summary,
        signalIds: accepted.map((signal) => signal.id),
        evidenceIds: evidence,
        issues: const [],
      ),
    );
  }

  ProprietaryBilIntelligenceResult _abstain(
    ProprietaryBilIntelligenceRequest request,
    String issue,
  ) {
    return _validated(
      ProprietaryBilIntelligenceResult(
        status: BilIntelligenceStatus.abstained,
        generatedAt: request.generatedAt,
        summary: '',
        signalIds: const [],
        evidenceIds: const [],
        issues: [issue],
      ),
    );
  }

  ProprietaryBilIntelligenceResult _validated(
    ProprietaryBilIntelligenceResult result,
  ) {
    final issues = integrityValidator.validateResult(result);
    if (issues.isEmpty) {
      return result;
    }
    return ProprietaryBilIntelligenceResult(
      status: BilIntelligenceStatus.rejected,
      generatedAt: result.generatedAt,
      summary: '',
      signalIds: const [],
      evidenceIds: const [],
      issues: issues,
    );
  }
}
