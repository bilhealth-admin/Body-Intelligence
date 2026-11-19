import 'dart:convert';
import '../domain/gemini_vision_estimate.dart';
import 'meal_image_gateway_contract.dart';

/// Schema2 is explicit. A schema1 response is never upgraded to estimates,
/// and Gemini estimates are never exposed as a verified catalog candidate.
MealImageAnalysis parseGeminiMealImageResponse(
  String body, {
  String languageCode = 'en',
}) {
  Never invalid() => throw const MealImageAnalysisException(
    MealImageAnalysisFailure.invalidResponse,
  );
  try {
    if (utf8.encode(body).length > maximumMealImageResponseBytes) invalid();
    final root = jsonDecode(body);
    if (root is! Map<String, dynamic> ||
        root['schema_version'] != 2 ||
        root['candidates'] is! List ||
        root['request_id'] is! String) {
      invalid();
    }
    final rows = root['candidates'] as List;
    if (rows.length > maximumMealImageCandidates) invalid();
    final identityRows = <Map<String, Object?>>[];
    for (final raw in rows) {
      if (raw is! Map<String, dynamic> ||
          raw.keys.any(
            (key) => !const {
              'name',
              'confidence',
              'evidence',
              'amount',
              'unit',
              'alternatives',
              'uncertainty',
              'warnings',
              'dish_identity',
              'visible_components',
              'provenance',
              'estimate',
            }.contains(key),
          )) {
        invalid();
      }
      final provenance = raw['provenance'];
      final estimate = raw['estimate'];
      if (provenance is! Map<String, dynamic> ||
          provenance.keys.any(
            (key) => !const {
              'identification_provider',
              'model_revision',
              'prompt_revision',
              'nutrition_resolution',
            }.contains(key),
          ) ||
          provenance['identification_provider'] != 'gemini' ||
          provenance['nutrition_resolution'] != 'gemini_photo_estimate' ||
          provenance['prompt_revision'] is! String ||
          estimate is! Map<String, dynamic> ||
          estimate.keys.any(
            (key) => !const {
              'kind',
              'basis',
              'nutrients',
              'uncertainty',
            }.contains(key),
          ) ||
          estimate['kind'] != 'gemini_photo_estimate') {
        invalid();
      }
      // Reuse the existing strict identity/locale validator only. This bridge
      // is never persisted or passed to catalog lookup; output below has its
      // own Gemini-estimate resolution and immutable nutrition provenance.
      identityRows.add({
        for (final key in const [
          'name',
          'confidence',
          'evidence',
          'amount',
          'unit',
          'alternatives',
          'uncertainty',
          'warnings',
          'dish_identity',
          'visible_components',
        ])
          if (raw.containsKey(key)) key: raw[key],
        'provenance': {
          'identification_provider': 'gemini',
          'model_revision': provenance['model_revision'],
          'nutrition_resolution': 'requires_verified_food_match',
        },
      });
    }
    final identity = parseMealImageResponse(
      jsonEncode({
        'schema_version': 1,
        'request_id': root['request_id'],
        'response_locale': root['response_locale'],
        'candidates': identityRows,
      }),
      languageCode: languageCode,
    );
    final estimates = <GeminiVisionEstimate>[];
    final candidates = <MealImageCandidate>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index] as Map<String, dynamic>;
      final source = row['provenance'] as Map<String, dynamic>;
      final data = row['estimate'] as Map<String, dynamic>;
      final candidate = identity.candidates[index];
      if (candidate.unit != null &&
          !const {'g', 'ml', 'piece'}.contains(candidate.unit)) {
        invalid();
      }
      final estimate = GeminiVisionEstimate(
        requestId: identity.requestId,
        index: index,
        name: candidate.name,
        modelRevision: candidate.modelRevision,
        promptRevision: source['prompt_revision'] as String,
        nutrients: GeminiEstimateNutrients.fromJson(data['nutrients']),
        basis: data['basis'] == null
            ? null
            : GeminiEstimateBasis.fromJson(data['basis']),
        picturedAmount: candidate.amount,
        picturedUnit: candidate.unit,
        uncertainty: data['uncertainty'] == null
            ? null
            : data['uncertainty'] as String,
      );
      estimates.add(estimate);
      candidates.add(
        MealImageCandidate(
          name: candidate.name,
          confidence: candidate.confidence,
          evidence: candidate.evidence,
          identificationProvider: 'gemini',
          modelRevision: candidate.modelRevision,
          nutritionResolution: MealNutritionResolution.geminiPhotoEstimate,
          amount: candidate.amount,
          unit: candidate.unit,
          alternatives: candidate.alternatives,
          uncertainty: candidate.uncertainty,
          warnings: candidate.warnings,
        ),
      );
    }
    return MealImageAnalysis(
      candidates: List.unmodifiable(candidates),
      notice: languageCode.split('-').first == 'ar'
          ? 'تقدير من صورتك. عدّل الحصة إذا احتجت.'
          : 'Estimated from your photo. Adjust the portion if needed.',
      requestId: identity.requestId,
      schemaVersion: 2,
      estimates: List.unmodifiable(estimates),
    );
  } on MealImageAnalysisException {
    rethrow;
  } on Object {
    invalid();
  }
}
