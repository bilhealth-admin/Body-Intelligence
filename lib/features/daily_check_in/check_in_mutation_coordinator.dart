enum CheckInMutationKind { save, delete, skip }

enum CheckInMutationOutcome { success, failure, alreadyBusy }

/// One mutation gate for every daily check-in write.
final class CheckInMutationCoordinator {
  CheckInMutationCoordinator({required this.onStateChanged});

  final void Function(CheckInMutationKind? active) onStateChanged;
  CheckInMutationKind? _active;

  CheckInMutationKind? get active => _active;
  bool get busy => _active != null;

  Future<CheckInMutationOutcome> run(
    CheckInMutationKind kind,
    Future<void> Function() operation,
  ) async {
    if (busy) return CheckInMutationOutcome.alreadyBusy;
    _active = kind;
    onStateChanged(kind);
    try {
      await operation();
      return CheckInMutationOutcome.success;
    } on Object {
      return CheckInMutationOutcome.failure;
    } finally {
      _active = null;
      onStateChanged(null);
    }
  }
}
