import 'dart:math';

enum StorePurchaseStage {
  tap,
  nativeLaunch,
  nativeLaunchReturned,
  nativeCallback,
  verificationStarted,
  serverProof,
  canonicalRead,
  benefitPublished,
  confirmationPainted,
  finishStarted,
  finishCompleted,
}

/// Monotonic app-side timings only. No receipt, account, health information,
/// balance or raw transaction identifier is logged or retained here.
final class StorePurchaseTrace {
  StorePurchaseTrace()
    : traceId = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join() {
    _clock.start();
    mark(StorePurchaseStage.tap);
  }
  final String traceId;
  final _clock = Stopwatch();
  final _stages = <StorePurchaseStage, int>{};
  void mark(StorePurchaseStage stage) =>
      _stages.putIfAbsent(stage, () => _clock.elapsedMicroseconds);
  Map<String, Object?> toSafeMap() => {
    'trace_id': traceId,
    'clock': 'monotonic_microseconds',
    'stages': {
      for (final entry in _stages.entries) entry.key.name: entry.value,
    },
  };
}

abstract final class StorePurchaseTraceRegistry {
  static final _traces = <String, StorePurchaseTrace>{};
  static void bind(String opaqueDeliveryKey, StorePurchaseTrace? trace) {
    if (trace == null) return;
    if (_traces.length >= 128) _traces.remove(_traces.keys.first);
    _traces[opaqueDeliveryKey] = trace;
  }

  static StorePurchaseTrace? forDelivery(String opaqueDeliveryKey) =>
      _traces[opaqueDeliveryKey];
}
