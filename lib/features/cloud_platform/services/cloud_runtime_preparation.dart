import 'cloud_runtime_access_gate.dart';

final class CloudRuntimePreparation {
  const CloudRuntimePreparation({
    required this.disposition,
    this.ownerId,
    this.enqueued = 0,
    this.remainingDirty = 0,
  });

  final CloudRuntimeAccessDisposition disposition;
  final String? ownerId;
  final int enqueued;
  final int remainingDirty;

  bool get prepared => disposition == CloudRuntimeAccessDisposition.ready;
}
