import 'body_twin_snapshot.dart';
import 'body_twin_snapshot_gate_result.dart';

/// Stable public outcome exposed by the deterministic Body Twin snapshot
/// foundation.
enum BodyTwinFoundationStatus { accepted, rejected }

/// Immutable public consumer boundary over one integrity-gated Body Twin
/// snapshot.
///
/// The complete gate result remains inspectable. A snapshot is exposed through
/// [acceptedSnapshot] only when the established validator and gate accepted the
/// same deterministic envelope.
final class BodyTwinFoundationResult {
  BodyTwinFoundationResult._({required this.gateResult, required this.status});

  factory BodyTwinFoundationResult.fromGate(
    BodyTwinSnapshotGateResult gateResult,
  ) {
    return BodyTwinFoundationResult._(
      gateResult: gateResult,
      status: gateResult.canProceed
          ? BodyTwinFoundationStatus.accepted
          : BodyTwinFoundationStatus.rejected,
    );
  }

  final BodyTwinSnapshotGateResult gateResult;
  final BodyTwinFoundationStatus status;

  bool get isAccepted => status == BodyTwinFoundationStatus.accepted;
  bool get isRejected => status == BodyTwinFoundationStatus.rejected;

  BodyTwinSnapshot? get acceptedSnapshot =>
      isAccepted ? gateResult.acceptedSnapshot : null;
}
