import '../core/global_platform_core.dart';
import '../platform/native_platform_bridges.dart';

abstract interface class WearableProvider {
  String get id;
  Future<Set<String>> capabilities();
  Future<WearableSyncBatch> pull({
    required String? cursor,
    required DateTime asOf,
  });
  Future<void> revoke();
}

final class WearableSyncBatch {
  const WearableSyncBatch({
    required this.signals,
    required this.deletedIds,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<GlobalHealthSignal> signals;
  final List<String> deletedIds;
  final String? nextCursor;
  final bool hasMore;
}

final class NativeWearableProvider implements WearableProvider {
  NativeWearableProvider({required this.bridge});
  final MethodChannelWearableBridge bridge;
  @override
  String get id => bridge.id;
  @override
  Future<Set<String>> capabilities() => bridge.capabilities();
  @override
  Future<void> revoke() => bridge.revoke();
  @override
  Future<WearableSyncBatch> pull({
    required String? cursor,
    required DateTime asOf,
  }) async {
    final raw = await bridge.synchronize(cursor: cursor, asOf: asOf);
    final signals = <GlobalHealthSignal>[];
    for (final item in raw['signals'] as List<Object?>? ?? const <Object?>[]) {
      final row = Map<String, Object?>.from(item! as Map);
      signals.add(GlobalHealthSignal.fromMap(row));
    }
    return WearableSyncBatch(
      signals: signals,
      deletedIds: List<String>.from(
        raw['deletedIds'] as List<Object?>? ?? const <Object?>[],
      ),
      nextCursor: raw['nextCursor'] as String?,
      hasMore: raw['hasMore'] == true,
    );
  }
}

final class WearableRuntime {
  WearableRuntime({
    required this.providers,
    required this.store,
    required this.audit,
    this.maxPages = 50,
  });
  final List<WearableProvider> providers;
  final GlobalDurableStore store;
  final GlobalAuditSink audit;
  final int maxPages;

  Future<List<GlobalHealthSignal>> synchronize(DateTime asOf) async {
    final all = <GlobalHealthSignal>[];
    for (final provider in providers) {
      try {
        var cursor =
            (await store.get('wearable_cursor', provider.id))?['value']
                as String?;
        var pages = 0;
        while (pages++ < maxPages) {
          final batch = await provider.pull(cursor: cursor, asOf: asOf);
          all.addAll(
            batch.signals.where(
              (signal) => !signal.provenance.observedAt.isAfter(asOf.toUtc()),
            ),
          );
          for (final deletedId in batch.deletedIds) {
            await store.put(
              'wearable_tombstones',
              '${provider.id}:$deletedId',
              <String, Object?>{
                'providerId': provider.id,
                'recordId': deletedId,
                'deletedAt': asOf.toUtc().toIso8601String(),
              },
            );
            await store.remove(
              'wearable_record_seen',
              '${provider.id}:$deletedId',
            );
          }
          cursor = batch.nextCursor;
          await store.put('wearable_cursor', provider.id, <String, Object?>{
            'value': cursor,
          });
          if (!batch.hasMore) break;
        }
      } catch (error) {
        await store.put('wearable_failures', provider.id, <String, Object?>{
          'error': error.runtimeType.toString(),
          'at': asOf.toUtc().toIso8601String(),
          'retryable': true,
        });
      }
    }
    final reconciled = _reconcile(all);
    await audit.record(
      GlobalAuditEvent(
        action: 'wearables.synchronized',
        subjectId: 'local-user',
        at: asOf,
        metadata: <String, Object?>{
          'records': reconciled.length,
          'providers': providers.length,
        },
      ),
    );
    return reconciled;
  }

  List<GlobalHealthSignal> _reconcile(List<GlobalHealthSignal> input) {
    final map = <String, GlobalHealthSignal>{};
    for (final signal in input) {
      final key =
          '${signal.key}:${signal.provenance.observedAt.millisecondsSinceEpoch ~/ 60000}';
      final prior = map[key];
      final score =
          signal.provenance.confidence +
          (signal.provenance.deviceId == null ? 0 : .05);
      final priorScore = prior == null
          ? -1
          : prior.provenance.confidence +
                (prior.provenance.deviceId == null ? 0 : .05);
      if (score > priorScore ||
          (score == priorScore &&
              signal.identity.compareTo(prior!.identity) < 0)) {
        map[key] = signal;
      }
    }
    return map.values.toList()..sort(
      (a, b) => a.provenance.observedAt.compareTo(b.provenance.observedAt),
    );
  }
}
