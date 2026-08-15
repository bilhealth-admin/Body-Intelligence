import '../../data/repositories/water_repository.dart';

enum WaterMutationOutcome { success, failure, alreadyBusy }

/// Serializes water mutations shared by the diary controls.
///
/// The UI listens to [onBusyChanged] so every input/navigation affordance is
/// locked for the same operation window. Repository failures are returned to
/// the caller and never optimistically remove a visible entry.
final class WaterMutationCoordinator {
  WaterMutationCoordinator({required this.onBusyChanged});

  final void Function(bool busy) onBusyChanged;
  bool _busy = false;

  bool get busy => _busy;

  Future<WaterMutationOutcome> add({
    required WaterRepository repository,
    required DateTime occurredAt,
    required int amountMl,
  }) => _run(() async {
    await repository.add(occurredAt: occurredAt, amountMl: amountMl);
  });

  Future<WaterMutationOutcome> delete({
    required WaterRepository repository,
    required int id,
  }) => _run(() => repository.delete(id));

  Future<WaterMutationOutcome> _run(Future<void> Function() operation) async {
    if (_busy) return WaterMutationOutcome.alreadyBusy;
    _busy = true;
    onBusyChanged(true);
    try {
      await operation();
      return WaterMutationOutcome.success;
    } on Object {
      return WaterMutationOutcome.failure;
    } finally {
      _busy = false;
      onBusyChanged(false);
    }
  }
}
