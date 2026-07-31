import 'ai_evidence.dart';
import 'truth_signal.dart';

/// Deterministic typed rule capable of producing one explainable truth signal.
///
/// Rule predicates must be pure and local. The rule itself never calls a
/// provider, accesses the network, reads a clock, or mutates application state.
final class TruthRule<T> {
  factory TruthRule({
    required String key,
    required String propositionKey,
    required TruthSignalDirection direction,
    required double strength,
    required double reliability,
    required bool Function(T context) matches,
    required AiEvidence Function(T context) evidence,
  }) {
    return TruthRule._(
      _validatedText(key, 'key'),
      _validatedText(propositionKey, 'propositionKey'),
      direction,
      _validatedUnitInterval(strength, 'strength'),
      _validatedUnitInterval(reliability, 'reliability'),
      matches,
      evidence,
    );
  }

  const TruthRule._(
    this.key,
    this.propositionKey,
    this.direction,
    this.strength,
    this.reliability,
    this._matches,
    this._evidence,
  );

  final String key;
  final String propositionKey;
  final TruthSignalDirection direction;
  final double strength;
  final double reliability;
  final bool Function(T context) _matches;
  final AiEvidence Function(T context) _evidence;

  TruthSignal? evaluate(T context) {
    if (!_matches(context)) {
      return null;
    }
    return TruthSignal(
      key: key,
      direction: direction,
      strength: strength,
      reliability: reliability,
      evidence: _evidence(context),
    );
  }

  static String _validatedText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }

  static double _validatedUnitInterval(double value, String field) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, field);
    }
    return value;
  }
}
