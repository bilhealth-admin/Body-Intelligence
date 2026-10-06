enum NutrientEvidenceState { unavailable, partial, complete }

class NutrientObservation {
  const NutrientObservation({required this.value, required this.available});
  final double value;
  final bool available;
}

class NutrientEvidenceReport {
  const NutrientEvidenceReport({required this.state, required this.total});
  final NutrientEvidenceState state;
  final double? total;

  /// A partial known subtotal cannot stand in for the day's full intake.
  /// [total] remains available to views explicitly labelled as partial.
  double? get completeTotal =>
      state == NutrientEvidenceState.complete ? total : null;
}

class NutrientEvidenceEngine {
  const NutrientEvidenceEngine._();

  static NutrientEvidenceReport total(List<NutrientObservation> observations) {
    final known = observations.where((item) => item.available).toList();
    if (known.isEmpty) {
      return const NutrientEvidenceReport(
        state: NutrientEvidenceState.unavailable,
        total: null,
      );
    }
    return NutrientEvidenceReport(
      state: known.length == observations.length
          ? NutrientEvidenceState.complete
          : NutrientEvidenceState.partial,
      total: known.fold<double>(0, (sum, item) => sum + item.value),
    );
  }
}
