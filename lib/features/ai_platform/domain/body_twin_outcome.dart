import 'body_twin_snapshot.dart';
import 'trusted_body_twin_snapshot_result.dart';

/// Stable public classification for the deterministic Body Twin foundation.
enum BodyTwinOutcomeStatus { accepted, incomplete, rejected }

/// Immutable public consumer outcome over the trusted Body Twin pipeline.
///
/// The complete trusted result remains inspectable. A snapshot is exposed only
/// when every established integrity, completeness, freshness, and consistency
/// gate permits downstream use.
final class BodyTwinOutcome {
  const BodyTwinOutcome._({required this.trustedResult, required this.status});

  factory BodyTwinOutcome.fromTrustedResult(
    TrustedBodyTwinSnapshotResult trustedResult,
  ) {
    final foundationResult = trustedResult.foundationResult;
    late final BodyTwinOutcomeStatus status;

    if (trustedResult.canProceed) {
      status = BodyTwinOutcomeStatus.accepted;
    } else if (foundationResult.isAccepted &&
        foundationResult.acceptedSnapshot?.isComplete == false) {
      status = BodyTwinOutcomeStatus.incomplete;
    } else {
      status = BodyTwinOutcomeStatus.rejected;
    }

    return BodyTwinOutcome._(trustedResult: trustedResult, status: status);
  }

  final TrustedBodyTwinSnapshotResult trustedResult;
  final BodyTwinOutcomeStatus status;

  bool get isAccepted => status == BodyTwinOutcomeStatus.accepted;
  bool get isIncomplete => status == BodyTwinOutcomeStatus.incomplete;
  bool get isRejected => status == BodyTwinOutcomeStatus.rejected;
  bool get canProceed => isAccepted;

  BodyTwinSnapshot? get acceptedSnapshot =>
      canProceed ? trustedResult.acceptedSnapshot : null;
}
