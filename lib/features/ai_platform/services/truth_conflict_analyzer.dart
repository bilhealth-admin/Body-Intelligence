import '../domain/truth_conflict_analysis.dart';
import '../domain/truth_signal.dart';

/// Pure local analyzer that explains disagreement between truth signals.
///
/// It does not replace [TruthEngine], change thresholds, rank user actions,
/// access providers, use a clock, use randomness, or mutate application state.
final class TruthConflictAnalyzer {
  const TruthConflictAnalyzer({this.balanceTolerance = 0.05})
    : assert(balanceTolerance >= 0 && balanceTolerance <= 1);

  final double balanceTolerance;

  TruthConflictAnalysis analyze({required Iterable<TruthSignal> signals}) {
    final ordered = List<TruthSignal>.of(signals)
      ..sort((left, right) => left.key.compareTo(right.key));
    _requireUniqueKeys(ordered);

    final supporting = <String>[];
    final opposing = <String>[];
    var supportWeight = 0.0;
    var oppositionWeight = 0.0;

    for (final signal in ordered) {
      switch (signal.direction) {
        case TruthSignalDirection.supports:
          supporting.add(signal.key);
          supportWeight += signal.signedWeight;
        case TruthSignalDirection.opposes:
          opposing.add(signal.key);
          oppositionWeight += signal.signedWeight.abs();
      }
    }

    final margin = (supportWeight - oppositionWeight).abs();
    final status = _resolveStatus(
      supportingCount: supporting.length,
      opposingCount: opposing.length,
      supportWeight: supportWeight,
      oppositionWeight: oppositionWeight,
    );

    return TruthConflictAnalysis(
      status: status,
      supportingSignalKeys: supporting,
      opposingSignalKeys: opposing,
      supportWeight: supportWeight,
      oppositionWeight: oppositionWeight,
      margin: margin,
      rationale: _buildRationale(
        status: status,
        supportingCount: supporting.length,
        opposingCount: opposing.length,
        supportWeight: supportWeight,
        oppositionWeight: oppositionWeight,
        margin: margin,
      ),
    );
  }

  TruthConflictStatus _resolveStatus({
    required int supportingCount,
    required int opposingCount,
    required double supportWeight,
    required double oppositionWeight,
  }) {
    if (supportingCount == 0 || opposingCount == 0) {
      return TruthConflictStatus.none;
    }
    final total = supportWeight + oppositionWeight;
    final normalizedMargin = total == 0
        ? 0.0
        : (supportWeight - oppositionWeight).abs() / total;
    if (normalizedMargin <= balanceTolerance) {
      return TruthConflictStatus.balanced;
    }
    return supportWeight > oppositionWeight
        ? TruthConflictStatus.supportDominant
        : TruthConflictStatus.oppositionDominant;
  }

  String _buildRationale({
    required TruthConflictStatus status,
    required int supportingCount,
    required int opposingCount,
    required double supportWeight,
    required double oppositionWeight,
    required double margin,
  }) {
    return 'Conflict ${status.name} from $supportingCount supporting and '
        '$opposingCount opposing deterministic signal(s); '
        'support weight=${supportWeight.toStringAsFixed(3)}; '
        'opposition weight=${oppositionWeight.toStringAsFixed(3)}; '
        'absolute margin=${margin.toStringAsFixed(3)}.';
  }

  void _requireUniqueKeys(List<TruthSignal> signals) {
    final seen = <String>{};
    for (final signal in signals) {
      if (!seen.add(signal.key)) {
        throw ArgumentError.value(
          signal.key,
          'signals',
          'signal keys must be unique',
        );
      }
    }
  }
}
