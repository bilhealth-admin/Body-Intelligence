import 'ai_evidence.dart';

/// Direction of a deterministic signal relative to the proposition assessed.
enum TruthSignalDirection { supports, opposes }

/// BIL-owned input to the Truth Engine.
///
/// Signals must be produced by deterministic local engines. This contract does
/// not call providers, access the network, or infer medical diagnoses.
final class TruthSignal {
  TruthSignal({
    required this.key,
    required this.direction,
    required this.strength,
    required this.reliability,
    required this.evidence,
  }) {
    _requireText(key, 'key');
    _requireUnitInterval(strength, 'strength');
    _requireUnitInterval(reliability, 'reliability');
  }

  final String key;
  final TruthSignalDirection direction;

  /// Magnitude of this signal in the inclusive range 0..1.
  final double strength;

  /// Reliability of the deterministic source in the inclusive range 0..1.
  final double reliability;

  final AiEvidence evidence;

  double get signedWeight {
    final magnitude = strength * reliability;
    return direction == TruthSignalDirection.supports ? magnitude : -magnitude;
  }

  static void _requireText(String value, String field) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
  }

  static void _requireUnitInterval(double value, String field) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, field);
    }
  }
}
