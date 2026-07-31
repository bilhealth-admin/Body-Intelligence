import 'dart:collection';

/// Deterministic interpretation of opposing Truth Engine signals.
enum TruthConflictStatus { none, supportDominant, oppositionDominant, balanced }

/// Immutable, provider-neutral explanation of signal disagreement.
final class TruthConflictAnalysis {
  TruthConflictAnalysis({
    required this.status,
    required Iterable<String> supportingSignalKeys,
    required Iterable<String> opposingSignalKeys,
    required this.supportWeight,
    required this.oppositionWeight,
    required this.margin,
    required String rationale,
  }) : supportingSignalKeys = UnmodifiableListView<String>(
         _normalizedUnique(supportingSignalKeys, 'supportingSignalKeys'),
       ),
       opposingSignalKeys = UnmodifiableListView<String>(
         _normalizedUnique(opposingSignalKeys, 'opposingSignalKeys'),
       ),
       rationale = _validatedText(rationale, 'rationale') {
    _requireNonNegativeFinite(supportWeight, 'supportWeight');
    _requireNonNegativeFinite(oppositionWeight, 'oppositionWeight');
    _requireNonNegativeFinite(margin, 'margin');

    final overlap = this.supportingSignalKeys.toSet().intersection(
      this.opposingSignalKeys.toSet(),
    );
    if (overlap.isNotEmpty) {
      throw ArgumentError.value(
        overlap,
        'signalKeys',
        'supporting and opposing keys must be disjoint',
      );
    }
  }

  final TruthConflictStatus status;
  final List<String> supportingSignalKeys;
  final List<String> opposingSignalKeys;
  final double supportWeight;
  final double oppositionWeight;
  final double margin;
  final String rationale;

  bool get hasConflict =>
      supportingSignalKeys.isNotEmpty && opposingSignalKeys.isNotEmpty;

  static List<String> _normalizedUnique(Iterable<String> values, String field) {
    final normalized = values
        .map((value) => _validatedText(value, field))
        .toList(growable: false);
    if (normalized.toSet().length != normalized.length) {
      throw ArgumentError.value(values, field, 'must contain unique keys');
    }
    return normalized..sort();
  }

  static String _validatedText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }

  static void _requireNonNegativeFinite(double value, String field) {
    if (!value.isFinite || value < 0) {
      throw RangeError.value(value, field, 'must be finite and non-negative');
    }
  }
}
