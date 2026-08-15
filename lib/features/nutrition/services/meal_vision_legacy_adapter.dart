import '../domain/meal_vision_contract.dart';
import 'meal_image_gateway_contract.dart';

/// Preserves the existing gateway response while exposing the unified domain
/// contract. Amounts are deliberately not invented: legacy candidates use a
/// review-only unit and must be edited before logging.
MealVisionResult adaptLegacyMealImageAnalysis(
  MealImageAnalysis analysis, {
  required Duration latency,
  MealVisionUsage? usage,
  MealVisionCost? cost,
}) {
  final candidates = analysis.candidates;
  if (candidates.isEmpty) {
    throw const MealVisionException(MealVisionFailure.nonFood);
  }
  return MealVisionResult(
    items: List<MealVisionItem>.unmodifiable(
      candidates.map(
        (candidate) => MealVisionItem(
          normalizedName: candidate.name.trim(),
          amount: candidate.amount ?? 1,
          unit: candidate.unit ?? 'review-required',
          confidence: candidate.confidence,
          alternatives: <MealVisionAlternative>[
            for (final alternative in candidate.alternatives)
              MealVisionAlternative(
                normalizedName: alternative.name,
                confidence: alternative.confidence,
              ),
          ],
          uncertainty: candidate.uncertainty ??
              (candidate.evidence.trim().isEmpty
                  ? 'amount-and-unit-unresolved'
                  : candidate.evidence.trim()),
          warnings: <String>[
            ...candidate.warnings,
            if (candidate.amount == null || candidate.unit == null)
              'Serving amount and unit require explicit user review.',
          ],
        ),
      ),
    ),
    provider: candidates.first.identificationProvider,
    model: candidates.first.modelRevision,
    latency: latency,
    usage: usage,
    cost: cost,
    warnings: <String>[analysis.notice],
  );
}
