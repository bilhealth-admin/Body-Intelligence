import '../domain/barcode_identity.dart';
import '../domain/unified_food.dart';
import 'food_search_normalizer.dart';

enum BarcodeResolutionStatus { invalid, notFound, resolved, ambiguous }

class BarcodeResolution {
  final BarcodeIdentity identity;
  final BarcodeResolutionStatus status;
  final List<UnifiedFood> candidates;

  const BarcodeResolution({
    required this.identity,
    required this.status,
    required this.candidates,
  });

  UnifiedFood? get food =>
      status == BarcodeResolutionStatus.resolved ? candidates.single : null;

  bool get requiresDisambiguation =>
      status == BarcodeResolutionStatus.ambiguous;
}

class OfflineBarcodeResolver {
  const OfflineBarcodeResolver();

  BarcodeResolution resolve({
    required String barcode,
    required Iterable<UnifiedFood> foods,
  }) {
    final identity = BarcodeIdentity.parse(barcode);
    if (!identity.isValid) {
      return BarcodeResolution(
        identity: identity,
        status: BarcodeResolutionStatus.invalid,
        candidates: const <UnifiedFood>[],
      );
    }

    final matches =
        foods
            .where(
              (food) =>
                  FoodSearchNormalizer.normalizeBarcode(food.barcode ?? '') ==
                  identity.digits,
            )
            .toList(growable: false)
          ..sort(_compareCandidates);

    final status = switch (matches.length) {
      0 => BarcodeResolutionStatus.notFound,
      1 => BarcodeResolutionStatus.resolved,
      _ => BarcodeResolutionStatus.ambiguous,
    };
    return BarcodeResolution(
      identity: identity,
      status: status,
      candidates: List<UnifiedFood>.unmodifiable(matches),
    );
  }

  int _compareCandidates(UnifiedFood left, UnifiedFood right) {
    final verificationOrder = (right.verified ? 1 : 0).compareTo(
      left.verified ? 1 : 0,
    );
    if (verificationOrder != 0) return verificationOrder;

    final sourceOrder = _sourceRank(
      right.source,
    ).compareTo(_sourceRank(left.source));
    if (sourceOrder != 0) return sourceOrder;

    final nameOrder = left.name.toLowerCase().compareTo(
      right.name.toLowerCase(),
    );
    if (nameOrder != 0) return nameOrder;
    return left.id.compareTo(right.id);
  }

  int _sourceRank(FoodDataSource source) => switch (source) {
    FoodDataSource.foundation => 5,
    FoodDataSource.branded => 4,
    FoodDataSource.custom => 3,
    FoodDataSource.legacy => 2,
    FoodDataSource.unknown => 1,
  };
}
