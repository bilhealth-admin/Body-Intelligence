import 'dart:convert';

import '../../nutrition/domain/barcode_identity.dart';
import '../../nutrition/services/meal_image_gateway_contract.dart';
import '../domain/food_v2/coach_food_v2.dart';
import 'coach_media_attempt.dart';
import 'coach_media_catalog_entry.dart';

enum CoachMediaFoodSource { photo, barcode }

enum CoachMediaFoodIssue {
  invalidInput,
  invalidBarcode,
  noMatch,
  unavailable,
  staleRequest,
  selectionRequired,
  missingQuantity,
  missingDensity,
  missingUnitWeight,
  unsupportedUnit,
}

/// Recognition proposes a name and amount, never a food-source authority.
/// The request ID comes from the local host, not the recognition payload.
final class CoachMediaFoodInput {
  CoachMediaFoodInput({
    required this.source,
    required this.requestId,
    this.name,
    this.barcode,
    this.amount,
    this.unit,
    this.quantityKind = CoachFoodQuantityKind.estimated,
    this.recognitionConfidence,
  });

  factory CoachMediaFoodInput.fromUntrustedPhoto(
    Map<String, Object?> payload, {
    required String requestId,
  }) => CoachMediaFoodInput(
    source: CoachMediaFoodSource.photo,
    requestId: requestId,
    name: payload['name'] is String ? payload['name'] as String : null,
    amount: payload['amount'] is num
        ? (payload['amount'] as num).toDouble()
        : null,
    unit: payload['unit'] is String ? payload['unit'] as String : null,
    recognitionConfidence: payload['confidence'] is num
        ? (payload['confidence'] as num).toDouble()
        : null,
    // verified/source/USDA IDs/nutrients/density/quantity-kind are intentionally
    // absent. They cannot cross the recognition-to-catalog trust boundary.
  );

  final CoachMediaFoodSource source;
  final String requestId;
  final String? name;
  final String? barcode;
  final double? amount;
  final String? unit;
  final CoachFoodQuantityKind quantityKind;
  final double? recognitionConfidence;

  CoachMediaFoodInput withUserQuantity(double amount, String unit) =>
      CoachMediaFoodInput(
        source: source,
        requestId: requestId,
        name: name,
        barcode: barcode,
        amount: amount,
        unit: unit,
        quantityKind: CoachFoodQuantityKind.userDeclared,
        recognitionConfidence: recognitionConfidence,
      );

  bool get validIdentity =>
      RegExp(r'^[a-zA-Z0-9._:-]{1,160}$').hasMatch(requestId) &&
      (source == CoachMediaFoodSource.barcode ||
          name != null &&
              name!.trim().isNotEmpty &&
              name!.runes.length <= 200 &&
              !name!.runes.any((r) => r < 32 || r == 127));
}

/// Only the application-owned local catalog implementation supplies entries.
/// No model or provider JSON decoder can implement a verified result here.
typedef CoachMediaCatalogLookup =
    Future<List<CoachMediaCatalogEntry>> Function(CoachMediaFoodInput input);

sealed class CoachMediaFoodOutcome {
  const CoachMediaFoodOutcome();
}

final class CoachMediaFoodUnresolved extends CoachMediaFoodOutcome {
  const CoachMediaFoodUnresolved(this.issue);
  final CoachMediaFoodIssue issue;
}

/// Always requires explicit identity selection, including the one-hit case.
final class CoachMediaFoodMatches extends CoachMediaFoodOutcome {
  CoachMediaFoodMatches._(
    this.input,
    this.attempt,
    Iterable<CoachMediaCatalogEntry> entries,
  ) : candidates = List.unmodifiable(entries);

  final CoachMediaFoodInput input;
  final CoachMediaAttempt attempt;
  final List<CoachMediaCatalogEntry> candidates;
  bool get ambiguous => candidates.length > 1;
}

/// A review proposal, never a commit receipt. It has no write capability.
final class CoachMediaFoodReady extends CoachMediaFoodOutcome {
  const CoachMediaFoodReady._({
    required this.review,
    required this.attempt,
    required this.input,
  });

  final CoachFoodReview review;
  final CoachMediaAttempt attempt;
  final CoachMediaFoodInput input;
}

final class CoachMediaFoodBridge {
  const CoachMediaFoodBridge({required this.lookupLocal});

  final CoachMediaCatalogLookup lookupLocal;

  Future<CoachMediaFoodOutcome> lookup({
    required CoachMediaFoodInput input,
    required CoachMediaAttempt attempt,
  }) async {
    if (!attempt.canAcceptResult) return _stale;
    if (!input.validIdentity) return _invalid;
    if (input.source == CoachMediaFoodSource.barcode &&
        !BarcodeIdentity.parse(input.barcode ?? '').isValid) {
      return const CoachMediaFoodUnresolved(CoachMediaFoodIssue.invalidBarcode);
    }
    try {
      final entries = await lookupLocal(input);
      if (!attempt.canAcceptResult) return _stale;
      final unique = <String, CoachMediaCatalogEntry>{};
      for (final entry in entries) {
        attempt.ownerScope.checkEvidence(entry.food.source);
        if (entry.unitRule != null) {
          attempt.ownerScope.checkEvidence(entry.unitRule!.source);
        }
        // A duplicate search hit may be collapsed only when its immutable
        // identity AND complete content agree. Distinct foods stay ambiguous.
        final rule = entry.unitRule;
        final identity = jsonEncode([
          entry.food.identity,
          entry.food.digest,
          if (rule != null)
            [
              rule.identity,
              rule.preparedState,
              rule.inputUnit,
              rule.gramsPerUnit,
              rule.source.toJson(),
            ],
        ]);
        unique[identity] = entry;
      }
      if (unique.isEmpty) {
        return const CoachMediaFoodUnresolved(CoachMediaFoodIssue.noMatch);
      }
      return CoachMediaFoodMatches._(input, attempt, unique.values);
    } on Object {
      return attempt.canAcceptResult
          ? const CoachMediaFoodUnresolved(CoachMediaFoodIssue.unavailable)
          : _stale;
    }
  }

  CoachMediaFoodOutcome select({
    required CoachMediaFoodMatches matches,
    required CoachMediaCatalogEntry selected,
    CoachMediaFoodInput? reviewedInput,
  }) {
    final attempt = matches.attempt;
    if (!attempt.canAcceptResult) return _stale;
    if (!matches.candidates.any((entry) => identical(entry, selected))) {
      return const CoachMediaFoodUnresolved(
        CoachMediaFoodIssue.selectionRequired,
      );
    }
    final input = reviewedInput ?? matches.input;
    if (input.source != matches.input.source ||
        input.requestId != matches.input.requestId ||
        input.name != matches.input.name ||
        input.barcode != matches.input.barcode) {
      return _invalid;
    }
    final amount = input.amount;
    if (amount == null ||
        !amount.isFinite ||
        amount < .001 ||
        amount > 100000) {
      return const CoachMediaFoodUnresolved(
        CoachMediaFoodIssue.missingQuantity,
      );
    }
    final unit = input.unit?.trim().toLowerCase();
    if (unit == null || unit.isEmpty) {
      return const CoachMediaFoodUnresolved(
        CoachMediaFoodIssue.missingQuantity,
      );
    }
    // Recognition confidence describes the proposed identity. It does not
    // measure the uncertainty of a guessed weight and cannot certify it.
    const CoachFoodConfidence? quantityConfidence = null;
    final description =
        '${input.source.name}:${input.requestId}; '
        '${input.quantityKind.wireName}; input=$amount $unit';
    try {
      final CoachFoodQuantity quantity;
      if (_massUnits.contains(unit)) {
        // Restrict this existing converter to its explicit mass branches.
        // Its matching-serving-unit fallback is not evidence of ml density.
        final grams = mealImageAmountInGrams(
          amount: amount,
          unit: unit,
          servingSize: selected.food.basisGrams,
          servingUnit: 'g',
        );
        if (grams == null) return _invalid;
        quantity = CoachFoodQuantities.declaredGrams(
          grams,
          description: description,
          kind: input.quantityKind,
          confidence: quantityConfidence,
        );
      } else if (unit == 'ml' || unit == 'item') {
        if (selected.unitRule == null || selected.unitRule!.inputUnit != unit) {
          return CoachMediaFoodUnresolved(
            unit == 'ml'
                ? CoachMediaFoodIssue.missingDensity
                : CoachMediaFoodIssue.missingUnitWeight,
          );
        }
        final converted = CoachFoodQuantities.fromUnit(
          food: selected.food,
          amount: amount,
          inputUnit: unit,
          rule: selected.unitRule,
          scope: attempt.ownerScope,
          description: description,
          confidence: quantityConfidence,
        );
        // A trusted density does not make a photo-estimated volume measured.
        quantity = CoachFoodQuantity(
          grams: converted.grams,
          evidence: CoachFoodQuantityEvidence(
            kind: input.quantityKind,
            description: description,
            confidence: quantityConfidence,
            conversion: converted.evidence.conversion,
          ),
        );
      } else {
        return const CoachMediaFoodUnresolved(
          CoachMediaFoodIssue.unsupportedUnit,
        );
      }
      final review = CoachFoodReview([
        CoachFoodPortion(food: selected.food, quantity: quantity),
      ]);
      review.checkOwner(attempt.ownerScope);
      if (!attempt.canAcceptResult) return _stale;
      return CoachMediaFoodReady._(
        review: review,
        attempt: attempt,
        input: input,
      );
    } on CoachFoodContractError catch (error) {
      if (!attempt.canAcceptResult) return _stale;
      return CoachMediaFoodUnresolved(switch (error.code) {
        'density_required' => CoachMediaFoodIssue.missingDensity,
        'unit_weight_required' ||
        'unit_rule_identity_mismatch' => CoachMediaFoodIssue.missingUnitWeight,
        _ => CoachMediaFoodIssue.invalidInput,
      });
    }
  }

  /// One host handoff for an entire reviewed image. If any item is unresolved,
  /// the host cannot supply it here and must ask the user before continuing.
  CoachFoodReview? takeReview(List<CoachMediaFoodReady> items) {
    if (items.isEmpty) return null;
    if (items.toSet().length != items.length) return null;
    final attempt = items.first.attempt;
    final requestId = items.first.input.requestId;
    if (items.any(
      (item) =>
          !identical(item.attempt, attempt) ||
          item.input.requestId != requestId,
    )) {
      return null;
    }
    if (!attempt.canAcceptResult) return null;
    try {
      final review = CoachFoodReview(items.expand((item) => item.review.items));
      review.checkOwner(attempt.ownerScope);
      return attempt.tryClaim() ? review : null;
    } on CoachFoodContractError {
      return null;
    }
  }

  static const _massUnits = {
    'g',
    'gram',
    'grams',
    'gm',
    'جم',
    'kg',
    'kilogram',
    'kilograms',
    'كجم',
    'oz',
    'ounce',
    'ounces',
    'lb',
    'lbs',
    'pound',
    'pounds',
    'mg',
    'milligram',
    'milligrams',
  };
  static const _stale = CoachMediaFoodUnresolved(
    CoachMediaFoodIssue.staleRequest,
  );
  static const _invalid = CoachMediaFoodUnresolved(
    CoachMediaFoodIssue.invalidInput,
  );
}
