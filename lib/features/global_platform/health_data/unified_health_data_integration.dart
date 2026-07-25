import '../core/global_platform_core.dart';

abstract interface class NativeHealthCapabilityBridge {
  Future<Map<String, Object?>> availability();
  Future<void> enableBackgroundDelivery(Set<String> types);
}

enum HealthDataType {
  steps,
  activeEnergy,
  workout,
  sleep,
  weight,
  bodyFat,
  leanMass,
  heartRate,
  restingHeartRate,
  hrv,
  oxygen,
  respiratoryRate,
  glucose,
  bloodPressureSystolic,
  bloodPressureDiastolic,
  water,
  nutrition,
}

final class NativeHealthRecord {
  NativeHealthRecord({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required DateTime observedAt,
    required this.sourceId,
    required this.deviceId,
    required this.confidence,
    required this.providerId,
    this.deleted = false,
    this.timeZoneId = 'UTC',
  }) : observedAt = observedAt.toUtc();

  factory NativeHealthRecord.fromMap(
    Map<String, Object?> map, {
    required String providerId,
  }) => NativeHealthRecord(
    id: map['id']! as String,
    type: HealthDataType.values.byName(map['type']! as String),
    value: (map['value']! as num).toDouble(),
    unit: map['unit']! as String,
    observedAt: DateTime.parse(map['observedAt']! as String),
    sourceId: map['sourceId']! as String,
    deviceId: map['deviceId'] as String?,
    confidence: (map['confidence'] as num? ?? 1).toDouble(),
    providerId: providerId,
    deleted: map['deleted'] == true,
    timeZoneId: map['timeZoneId'] as String? ?? 'UTC',
  );

  final String id;
  final HealthDataType type;
  final double value;
  final String unit;
  final DateTime observedAt;
  final String sourceId;
  final String? deviceId;
  final double confidence;
  final String providerId;
  final bool deleted;
  final String timeZoneId;
}

final class NativeHealthPage {
  const NativeHealthPage({
    required this.records,
    required this.deletedIds,
    required this.nextAnchor,
    required this.hasMore,
  });
  final List<NativeHealthRecord> records;
  final List<String> deletedIds;
  final String? nextAnchor;
  final bool hasMore;
}

abstract interface class NativeHealthBridge {
  String get id;
  Future<Map<String, bool>> permissions();
  Future<void> request(Set<String> types, {required bool write});
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  });
  Future<void> write(List<GlobalHealthSignal> signals);
  Future<void> delete(List<String> recordIds);
}

final class UnifiedHealthDataRuntime {
  UnifiedHealthDataRuntime({
    required this.bridges,
    required this.store,
    required this.audit,
    this.pageLimit = 100,
  });

  final List<NativeHealthBridge> bridges;
  final GlobalDurableStore store;
  final GlobalAuditSink audit;
  final int pageLimit;

  Future<List<GlobalHealthSignal>> synchronize({
    required DateTime asOf,
    required GlobalConsentGrant consent,
    Set<HealthDataType>? types,
  }) async {
    if (!consent.permits) return const <GlobalHealthSignal>[];
    final requestedTypes = types ?? HealthDataType.values.toSet();
    final collected = <GlobalHealthSignal>[];
    for (final bridge in bridges) {
      if (bridge is NativeHealthCapabilityBridge) {
        final capabilityBridge = bridge as NativeHealthCapabilityBridge;
        final availability = await capabilityBridge.availability();
        if (availability['available'] != true) {
          for (final bridge
              in bridges.whereType<NativeHealthCapabilityBridge>()) {
            await bridge.enableBackgroundDelivery(
              requestedTypes.map((type) => type.name).toSet(),
            );
          }
          await audit.record(
            GlobalAuditEvent(
              action: 'health.integration.unavailable',
              subjectId: bridge.id,
              at: asOf,
              metadata: <String, Object?>{
                'platform': availability['platform'],
                'status': availability['status'],
              },
            ),
          );
          continue;
        }
      }
      final permission = await bridge.permissions();
      final allowed = requestedTypes
          .where((type) => permission[type.name] == true)
          .map((e) => e.name)
          .toSet();
      if (allowed.isEmpty) continue;
      String? anchor =
          (await store.get('health_anchor', bridge.id))?['anchor'] as String?;
      var pages = 0;
      while (pages++ < pageLimit) {
        final page = await bridge.readChanges(
          anchor: anchor,
          asOf: asOf,
          types: allowed,
        );
        for (final deleted in page.deletedIds) {
          await store.put(
            'health_tombstones',
            '${bridge.id}:$deleted',
            <String, Object?>{
              'provider': bridge.id,
              'recordId': deleted,
              'at': asOf.toUtc().toIso8601String(),
            },
          );
        }
        for (final record in page.records) {
          if (record.observedAt.isAfter(asOf.toUtc())) continue;
          final identity = '${bridge.id}:${record.id}:${record.type.name}';
          if (await store.get('health_seen', identity) != null) continue;
          await store.put('health_seen', identity, <String, Object?>{
            'identity': identity,
          });
          collected.add(_normalize(record));
        }
        anchor = page.nextAnchor;
        await store.put('health_anchor', bridge.id, <String, Object?>{
          'anchor': anchor,
        });
        if (!page.hasMore) break;
      }
    }
    for (final bridge in bridges.whereType<NativeHealthCapabilityBridge>()) {
      await bridge.enableBackgroundDelivery(
        requestedTypes.map((type) => type.name).toSet(),
      );
    }
    await audit.record(
      GlobalAuditEvent(
        action: 'health.integration.synchronized',
        subjectId: consent.scope,
        at: asOf,
        metadata: <String, Object?>{
          'records': collected.length,
          'providers': bridges.length,
        },
      ),
    );
    return List<GlobalHealthSignal>.unmodifiable(collected);
  }

  Future<void> export({
    required NativeHealthBridge bridge,
    required GlobalConsentGrant writeConsent,
    required List<GlobalHealthSignal> signals,
  }) async {
    if (!writeConsent.permits) {
      throw StateError('Explicit write consent is required.');
    }
    await bridge.write(signals);
  }

  GlobalHealthSignal _normalize(NativeHealthRecord record) {
    var value = record.value;
    var unit = record.unit;
    if (record.type == HealthDataType.weight && unit == 'lb') {
      value = value / 2.2046226218;
      unit = 'kg';
    }
    if (record.type == HealthDataType.glucose && unit == 'mmol/L') {
      value = value * 18;
      unit = 'mg/dL';
    }
    return GlobalHealthSignal(
      key: record.type.name,
      canonicalValue: value,
      canonicalUnit: unit,
      deleted: record.deleted,
      provenance: GlobalProvenance(
        providerId: record.providerId,
        sourceId: record.sourceId,
        recordId: record.id,
        observedAt: record.observedAt,
        confidence: record.confidence.clamp(0, 1),
        deviceId: record.deviceId,
        timeZoneId: record.timeZoneId,
      ),
    );
  }
}
