import 'body_twin_consistency_result.dart';
import 'body_twin_foundation_result.dart';
import 'body_twin_freshness_result.dart';
import 'body_twin_snapshot.dart';

/// Immutable evidence chain for a locally constructed, validated, fresh, and
/// consistent Body Twin snapshot.
final class TrustedBodyTwinSnapshotResult {
  const TrustedBodyTwinSnapshotResult({
    required this.foundationResult,
    required this.freshnessResult,
    required this.consistencyResult,
  });

  final BodyTwinFoundationResult foundationResult;
  final BodyTwinFreshnessResult freshnessResult;
  final BodyTwinConsistencyResult consistencyResult;

  /// Required-metric completeness remains an explicit trust boundary.
  ///
  /// The integrity validator intentionally validates envelope consistency and
  /// does not redefine an incomplete snapshot as structurally invalid. This
  /// composed result therefore blocks consumption unless the accepted upstream
  /// snapshot also contains every caller-declared required metric.
  bool get hasCompleteFoundation =>
      foundationResult.acceptedSnapshot?.isComplete == true;

  bool get canProceed =>
      hasCompleteFoundation &&
      freshnessResult.canProceed &&
      consistencyResult.canProceed;

  BodyTwinSnapshot? get acceptedSnapshot =>
      canProceed ? consistencyResult.acceptedConsistentSnapshot : null;
}
