enum MealVisionFailure { malformed, nonFood, lowConfidence, providerFailure }

class MealVisionException implements Exception {
  const MealVisionException(this.failure, {this.detail});

  final MealVisionFailure failure;
  final String? detail;

  @override
  String toString() => 'MealVisionException(${failure.name})';
}

class MealVisionAlternative {
  const MealVisionAlternative({
    required this.normalizedName,
    required this.confidence,
  });

  final String normalizedName;
  final double confidence;
}

class MealVisionItem {
  const MealVisionItem({
    required this.normalizedName,
    required this.amount,
    required this.unit,
    required this.confidence,
    this.alternatives = const <MealVisionAlternative>[],
    this.uncertainty,
    this.warnings = const <String>[],
  });

  final String normalizedName;
  final double amount;
  final String unit;
  final double confidence;
  final List<MealVisionAlternative> alternatives;
  final String? uncertainty;
  final List<String> warnings;

  bool get requiresReview => true;
}

class MealVisionUsage {
  const MealVisionUsage({
    this.inputUnits = 0,
    this.outputUnits = 0,
    this.images = 1,
  });

  final int inputUnits;
  final int outputUnits;
  final int images;
}

class MealVisionCost {
  const MealVisionCost({required this.amount, required this.currency});

  final double amount;
  final String currency;
}

class MealVisionResult {
  const MealVisionResult({
    required this.items,
    required this.provider,
    required this.model,
    required this.latency,
    this.usage,
    this.cost,
    this.warnings = const <String>[],
  });

  final List<MealVisionItem> items;
  final List<String> warnings;
  final String provider;
  final String model;
  final Duration latency;
  final MealVisionUsage? usage;
  final MealVisionCost? cost;

  /// Vision output is always a proposal. Only an explicit review workflow may
  /// convert a selected item into a verified food/meal record.
  bool get requiresReview => true;
  bool get canAutoLog => false;

  Map<String, Object?> toMap() => <String, Object?>{
    'items': <Map<String, Object?>>[
      for (final item in items)
        <String, Object?>{
          'normalized_name': item.normalizedName,
          'amount': item.amount,
          'unit': item.unit,
          'confidence': item.confidence,
          'alternatives': <Map<String, Object?>>[
            for (final alternative in item.alternatives)
              <String, Object?>{
                'normalized_name': alternative.normalizedName,
                'confidence': alternative.confidence,
              },
          ],
          'uncertainty': item.uncertainty,
          'warnings': item.warnings,
        },
    ],
    'warnings': warnings,
    'provider': provider,
    'model': model,
    'latency_ms': latency.inMilliseconds,
    'usage': usage == null
        ? null
        : <String, Object?>{
            'input_units': usage!.inputUnits,
            'output_units': usage!.outputUnits,
            'images': usage!.images,
          },
    'cost': cost == null
        ? null
        : <String, Object?>{'amount': cost!.amount, 'currency': cost!.currency},
    'requires_review': true,
    'can_auto_log': false,
  };

  factory MealVisionResult.fromMap(Map<String, Object?> map) {
    try {
      final rawItems = map['items'] as List<Object?>;
      final usage = map['usage'] == null
          ? null
          : Map<String, Object?>.from(map['usage']! as Map);
      final cost = map['cost'] == null
          ? null
          : Map<String, Object?>.from(map['cost']! as Map);
      return MealVisionResult(
        items: List<MealVisionItem>.unmodifiable(
          rawItems.map((raw) {
            final item = Map<String, Object?>.from(raw! as Map);
            final alternatives =
                item['alternatives'] as List<Object?>? ?? const [];
            return MealVisionItem(
              normalizedName: item['normalized_name']! as String,
              amount: (item['amount']! as num).toDouble(),
              unit: item['unit']! as String,
              confidence: (item['confidence']! as num).toDouble(),
              alternatives: List<MealVisionAlternative>.unmodifiable(
                alternatives.map((rawAlternative) {
                  final alternative = Map<String, Object?>.from(
                    rawAlternative! as Map,
                  );
                  return MealVisionAlternative(
                    normalizedName: alternative['normalized_name']! as String,
                    confidence: (alternative['confidence']! as num).toDouble(),
                  );
                }),
              ),
              uncertainty: item['uncertainty'] as String?,
              warnings: List<String>.unmodifiable(
                (item['warnings'] as List<Object?>? ?? const []).cast<String>(),
              ),
            );
          }),
        ),
        warnings: List<String>.unmodifiable(
          (map['warnings'] as List<Object?>? ?? const []).cast<String>(),
        ),
        provider: map['provider']! as String,
        model: map['model']! as String,
        latency: Duration(milliseconds: map['latency_ms']! as int),
        usage: usage == null
            ? null
            : MealVisionUsage(
                inputUnits: usage['input_units']! as int,
                outputUnits: usage['output_units']! as int,
                images: usage['images']! as int,
              ),
        cost: cost == null
            ? null
            : MealVisionCost(
                amount: (cost['amount']! as num).toDouble(),
                currency: cost['currency']! as String,
              ),
      );
    } catch (_) {
      throw const MealVisionException(MealVisionFailure.malformed);
    }
  }
}

class MealVisionRequest {
  const MealVisionRequest({
    required this.bytes,
    required this.mimeType,
    required this.locale,
  });

  final List<int> bytes;
  final String mimeType;
  final String locale;
}

abstract interface class MealVisionProvider {
  String get providerId;
  String get modelId;

  Future<MealVisionResult> analyze(MealVisionRequest request);
}

class MealVisionCoordinator {
  const MealVisionCoordinator({this.minimumConfidence = 0.55});

  final double minimumConfidence;

  Future<MealVisionResult> analyze(
    MealVisionProvider provider,
    MealVisionRequest request,
  ) async {
    MealVisionResult result;
    try {
      result = await provider.analyze(request);
    } on MealVisionException {
      rethrow;
    } catch (_) {
      throw const MealVisionException(MealVisionFailure.providerFailure);
    }
    _validate(result, provider);
    return result;
  }

  void _validate(MealVisionResult result, MealVisionProvider provider) {
    if (result.provider.trim().isEmpty ||
        result.model.trim().isEmpty ||
        result.provider != provider.providerId ||
        result.model != provider.modelId ||
        result.latency.isNegative ||
        (result.cost != null &&
            (result.cost!.amount < 0 ||
                !result.cost!.amount.isFinite ||
                result.cost!.currency.trim().isEmpty)) ||
        (result.usage != null &&
            (result.usage!.inputUnits < 0 ||
                result.usage!.outputUnits < 0 ||
                result.usage!.images < 0))) {
      throw const MealVisionException(MealVisionFailure.malformed);
    }
    if (result.items.isEmpty) {
      throw const MealVisionException(MealVisionFailure.nonFood);
    }
    for (final item in result.items) {
      if (item.normalizedName.trim().isEmpty ||
          item.amount <= 0 ||
          !item.amount.isFinite ||
          item.unit.trim().isEmpty ||
          !_confidence(item.confidence) ||
          item.alternatives.any(
            (alternative) =>
                alternative.normalizedName.trim().isEmpty ||
                !_confidence(alternative.confidence),
          )) {
        throw const MealVisionException(MealVisionFailure.malformed);
      }
    }
    if (result.items.every((item) => item.confidence < minimumConfidence)) {
      throw const MealVisionException(MealVisionFailure.lowConfidence);
    }
  }

  static bool _confidence(double value) =>
      value.isFinite && value >= 0 && value <= 1;
}
