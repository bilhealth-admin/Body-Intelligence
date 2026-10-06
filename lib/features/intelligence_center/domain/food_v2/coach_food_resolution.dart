part of 'coach_food_v2.dart';

/// The caller's real account observer must advance epoch on every switch,
/// including A → B → A. Use an opaque local account key rather than a label.
final class CoachFoodOwnerStamp {
  CoachFoodOwnerStamp({required String ownerKey, required this.epoch})
    : ownerKey = _foodText(ownerKey, 'ownerKey', 128) {
    if (epoch < 0 || epoch > 9007199254740991) {
      _foodReject('invalid_owner_epoch');
    }
  }

  final String ownerKey;
  final int epoch;
}

final class CoachFoodOwnerScope {
  CoachFoodOwnerScope({required this.captured, required this.readCurrent});

  final CoachFoodOwnerStamp captured;
  final CoachFoodOwnerStamp Function() readCurrent;
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  void check() {
    if (_cancelled) _foodReject('owner_changed');
    final current = readCurrent();
    if (current.ownerKey != captured.ownerKey ||
        current.epoch != captured.epoch) {
      _cancelled = true;
      _foodReject('owner_changed');
    }
  }

  void checkEvidence(CoachFoodSourceEvidence evidence) {
    check();
    if (evidence.ownerKey != null && evidence.ownerKey != captured.ownerKey) {
      _foodReject('evidence_owner_mismatch');
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    check();
    try {
      return await action();
    } finally {
      check();
    }
  }
}

final class CoachFoodQuery {
  CoachFoodQuery({
    required String concept,
    required String preparedState,
    required String localeTag,
  }) : concept = _foodText(concept, 'concept', 200),
       preparedState = _foodText(preparedState, 'preparedState', 120),
       localeTag = _foodText(localeTag, 'localeTag', 35);

  final String concept;
  final String preparedState;
  final String localeTag;
}

/// Trusted adapters attest the exact identity match. Search similarity and
/// model confidence alone cannot turn a different preparation into a match.
final class CoachFoodCandidate {
  CoachFoodCandidate({
    required String concept,
    required this.food,
    this.identityConfidence,
    this.unitRule,
  }) : concept = _foodText(concept, 'concept', 200) {
    final rule = unitRule;
    if (rule != null &&
        (rule.identity != food.identity ||
            rule.preparedState != food.preparedState)) {
      _foodReject('unit_rule_identity_mismatch');
    }
  }

  final String concept;
  final CoachFoodSnapshot food;
  final CoachFoodConfidence? identityConfidence;
  final CoachFoodUnitRule? unitRule;
}

/// All callbacks are injected. This module has no network, cache or provider
/// defaults, and never calls the existing network-first search implicitly.
final class CoachFoodResolverPorts {
  const CoachFoodResolverPorts({
    required this.fixed,
    required this.catalog,
    required this.reference,
    required this.estimate,
  });

  final Future<CoachFoodCandidate?> Function(
    String ownerKey,
    CoachFoodQuery query,
  )
  fixed;
  final Future<List<CoachFoodCandidate>> Function(CoachFoodQuery query) catalog;
  final Future<List<CoachFoodCandidate>> Function(CoachFoodQuery query)
  reference;
  final Future<CoachFoodCandidate> Function(CoachFoodQuery query) estimate;
}

enum CoachFoodResolutionPath { userFixed, catalog, reference, estimate }

enum CoachFoodClarificationReason { ambiguousIdentity, missingReference }

sealed class CoachFoodResolution {
  const CoachFoodResolution();
}

final class CoachResolvedFood extends CoachFoodResolution {
  const CoachResolvedFood._({required this.candidate, required this.path});

  final CoachFoodCandidate candidate;
  final CoachFoodResolutionPath path;
  CoachFoodSnapshot get food => candidate.food;
}

final class CoachFoodClarification extends CoachFoodResolution {
  const CoachFoodClarification(this.reason);
  final CoachFoodClarificationReason reason;
}

abstract final class CoachFoodResolver {
  static Future<CoachFoodResolution> resolve({
    required CoachFoodQuery query,
    required CoachFoodOwnerScope scope,
    required CoachFoodResolverPorts ports,
    bool allowEstimate = false,
  }) async {
    final fixed = await scope._guard(
      () => ports.fixed(scope.captured.ownerKey, query),
    );
    if (fixed != null) {
      if (!_matches(fixed, query)) _foodReject('fixed_food_identity_mismatch');
      if (fixed.food.source.kind != CoachFoodSourceKind.userFixed) {
        _foodReject('fixed_source_not_authorized');
      }
      _checkCandidate(fixed, scope);
      return CoachResolvedFood._(
        candidate: fixed,
        path: CoachFoodResolutionPath.userFixed,
      );
    }
    for (final path in [
      CoachFoodResolutionPath.catalog,
      CoachFoodResolutionPath.reference,
    ]) {
      final candidates = await scope._guard(
        () => path == CoachFoodResolutionPath.catalog
            ? ports.catalog(query)
            : ports.reference(query),
      );
      final matches = candidates
          .where((candidate) => _matches(candidate, query))
          .toList(growable: false);
      if (matches.length > 1) {
        return const CoachFoodClarification(
          CoachFoodClarificationReason.ambiguousIdentity,
        );
      }
      if (matches.isEmpty) continue;
      final match = matches.single;
      if (!const {
        CoachFoodSourceKind.reference,
        CoachFoodSourceKind.label,
        CoachFoodSourceKind.calculatedRecipe,
      }.contains(match.food.source.kind)) {
        _foodReject('untrusted_resolver_source');
      }
      _checkCandidate(match, scope);
      return CoachResolvedFood._(candidate: match, path: path);
    }
    if (!allowEstimate) {
      return const CoachFoodClarification(
        CoachFoodClarificationReason.missingReference,
      );
    }
    final estimated = await scope._guard(() => ports.estimate(query));
    if (!_matches(estimated, query)) _foodReject('estimate_identity_mismatch');
    final raw = estimated.food;
    scope.checkEvidence(raw.source);
    final contentRevision = _foodDigest({
      'concept': query.concept,
      'name': raw.name,
      'preparedState': raw.preparedState,
      'basisGrams': raw.basisGrams,
      'nutrients': raw.nutrients.toJson(),
    });
    CoachFoodConfidence? modelConfidence(
      CoachFoodConfidence? value,
      String basis,
    ) => value == null
        ? null
        : CoachFoodConfidence(score: value.score, basis: basis);
    // A generative fallback cannot award itself reference/USDA or user-fixed
    // authority. It also cannot attach an unreviewed portion rule as approved.
    final candidate = CoachFoodCandidate(
      concept: estimated.concept,
      identityConfidence: modelConfidence(
        estimated.identityConfidence,
        'model_reported_identity',
      ),
      food: CoachFoodSnapshot(
        identity: 'estimate:$contentRevision',
        name: raw.name,
        preparedState: raw.preparedState,
        basisGrams: raw.basisGrams,
        nutrients: raw.nutrients,
        source: CoachFoodSourceEvidence(
          kind: CoachFoodSourceKind.estimated,
          ref: 'local-estimate:$contentRevision',
          revision: 'sha256:$contentRevision',
          confidence: modelConfidence(
            raw.source.confidence,
            'model_reported_estimate',
          ),
        ),
      ),
    );
    scope.check();
    return CoachResolvedFood._(
      candidate: candidate,
      path: CoachFoodResolutionPath.estimate,
    );
  }

  static bool _matches(CoachFoodCandidate candidate, CoachFoodQuery query) =>
      candidate.concept == query.concept &&
      candidate.food.preparedState == query.preparedState;

  static void _checkCandidate(
    CoachFoodCandidate candidate,
    CoachFoodOwnerScope scope,
  ) {
    scope.checkEvidence(candidate.food.source);
    if (candidate.unitRule != null) {
      scope.checkEvidence(candidate.unitRule!.source);
    }
  }
}
