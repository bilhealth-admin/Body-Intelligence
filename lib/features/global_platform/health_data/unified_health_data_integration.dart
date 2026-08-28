import '../core/global_platform_core.dart';

abstract interface class NativeHealthCapabilityBridge {
  Future<Map<String, Object?>> availability();
  Future<void> enableBackgroundDelivery(Set<String> types);
  Future<Map<String, Object?>> revokeAccess();
  Future<void> openSettings();
}

/// Health signals BIL can read after the user explicitly authorizes them.
/// Missing types remain missing evidence; BIL never synthesizes them.
abstract final class BilHealthScope {
  static const Set<HealthDataType> read = <HealthDataType>{
    HealthDataType.steps,
    HealthDataType.distance,
    HealthDataType.activeEnergy,
    HealthDataType.workout,
    HealthDataType.sleep,
    HealthDataType.weight,
    HealthDataType.bodyFat,
    HealthDataType.leanMass,
    HealthDataType.heartRate,
    HealthDataType.restingHeartRate,
    HealthDataType.hrv,
    HealthDataType.water,
    HealthDataType.nutrition,
    HealthDataType.nutritionProtein,
    HealthDataType.nutritionCarbohydrates,
    HealthDataType.nutritionFat,
    HealthDataType.nutritionFiber,
    HealthDataType.nutritionSugar,
    HealthDataType.nutritionSodium,
    HealthDataType.nutritionPotassium,
  };

  static const Set<HealthDataType> write = <HealthDataType>{
    HealthDataType.weight,
    HealthDataType.nutrition,
  };

  /// Reject every provider key that is not part of the explicit fitness-only
  /// contract. This positive allow-list also safely drops unknown historical
  /// observations without retaining clinical identifiers in the runtime.
  static bool excludesKey(Object? rawKey) {
    final key = rawKey?.toString().trim().toLowerCase().replaceAll(
      RegExp('[^a-z0-9]'),
      '',
    );
    return !const <String>{
      'steps',
      'distance',
      'activeenergy',
      'workout',
      'exercise',
      'sleep',
      'weight',
      'bodyfat',
      'bodycomposition',
      'leanmass',
      'heartrate',
      'restingheartrate',
      'hrv',
      'water',
      'nutrition',
      'nutritionprotein',
      'nutritioncarbohydrates',
      'nutritionfat',
      'nutritionfiber',
      'nutritionsugar',
      'nutritionsodium',
      'nutritionpotassium',
    }.contains(key);
  }
}

/// Resolves duplicate observations without erasing their provenance. Explicit
/// manual input wins an exact-time conflict; otherwise confidence and recency
/// decide. The losing record remains persisted as evidence.
abstract final class HealthSignalConflictResolver {
  static GlobalHealthSignal prefer(
    GlobalHealthSignal current,
    GlobalHealthSignal candidate,
  ) {
    final currentManual = _manual(current);
    final candidateManual = _manual(candidate);
    final separation = current.provenance.observedAt
        .difference(candidate.provenance.observedAt)
        .abs();
    if (currentManual != candidateManual &&
        separation <= const Duration(hours: 24)) {
      return candidateManual ? candidate : current;
    }
    if (candidate.provenance.confidence != current.provenance.confidence) {
      return candidate.provenance.confidence > current.provenance.confidence
          ? candidate
          : current;
    }
    return candidate.provenance.observedAt.isAfter(
          current.provenance.observedAt,
        )
        ? candidate
        : current;
  }

  static bool _manual(GlobalHealthSignal signal) =>
      signal.provenance.providerId == 'manual' ||
      signal.provenance.sourceId == 'manual';
}

enum HealthDataType {
  steps,
  distance,
  activeEnergy,
  workout,
  sleep,
  weight,
  bodyFat,
  leanMass,
  heartRate,
  restingHeartRate,
  hrv,
  water,
  nutrition,
  nutritionProtein,
  nutritionCarbohydrates,
  nutritionFat,
  nutritionFiber,
  nutritionSugar,
  nutritionSodium,
  nutritionPotassium,
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
    Map<String, Object?> attributes = const <String, Object?>{},
  }) : observedAt = observedAt.toUtc(),
       attributes = Map<String, Object?>.unmodifiable(attributes);

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
    attributes: Map<String, Object?>.from(
      map['attributes'] as Map? ?? const <String, Object?>{},
    ),
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
  final Map<String, Object?> attributes;
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
    final requestedTypes = (types ?? BilHealthScope.read)
        .where(BilHealthScope.read.contains)
        .toSet();
    if (requestedTypes.isEmpty) return const <GlobalHealthSignal>[];
    final scopeSignature = requestedTypes.map((type) => type.name).toList()
      ..sort();
    final collected = <GlobalHealthSignal>[];
    final backgroundEligible = <NativeHealthCapabilityBridge>[];
    for (final bridge in bridges) {
      if (bridge is NativeHealthCapabilityBridge) {
        final capabilityBridge = bridge as NativeHealthCapabilityBridge;
        final availability = await capabilityBridge.availability();
        if (availability['available'] != true) {
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
        backgroundEligible.add(capabilityBridge);
      }
      final permission = await bridge.permissions();
      final allowed = requestedTypes
          .where((type) => permission[type.name] == true)
          .map((e) => e.name)
          .toSet();
      if (allowed.isEmpty) continue;
      final anchorState = await store.get('health_anchor', bridge.id);
      final anchor =
          anchorState != null &&
              anchorState['scope'] == scopeSignature.join(',')
          ? anchorState['anchor'] as String?
          : null;
      var nextAnchor = anchor;
      var pages = 0;
      while (pages++ < pageLimit) {
        final page = await bridge.readChanges(
          anchor: nextAnchor,
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
          if (!BilHealthScope.read.contains(record.type)) {
            await audit.record(
              GlobalAuditEvent(
                action: 'health.record.rejected',
                subjectId: '${bridge.id}:${record.id}:${record.type.name}',
                at: asOf,
                metadata: const <String, Object?>{
                  'reason': 'outside_fitness_scope',
                },
              ),
            );
            continue;
          }
          final identity = '${bridge.id}:${record.id}:${record.type.name}';
          final fingerprint =
              '${record.value}:${record.unit}:${record.observedAt.toIso8601String()}:${record.deleted}';
          final seen = await store.get('health_seen', identity);
          if (seen?['fingerprint'] == fingerprint) continue;
          final normalized = _normalize(record);
          if (normalized != null) {
            await store.put('health_seen', identity, <String, Object?>{
              'identity': identity,
              'fingerprint': fingerprint,
              'updatedAt': asOf.toUtc().toIso8601String(),
            });
            await store.put(
              'health_signals',
              normalized.identity,
              normalized.toMap(),
            );
            collected.add(normalized);
          } else {
            await audit.record(
              GlobalAuditEvent(
                action: 'health.record.rejected',
                subjectId: identity,
                at: asOf,
                metadata: <String, Object?>{'reason': 'invalid_value_or_unit'},
              ),
            );
          }
        }
        nextAnchor = page.nextAnchor;
        await store.put('health_anchor', bridge.id, <String, Object?>{
          'anchor': nextAnchor,
          'scope': scopeSignature.join(','),
        });
        if (!page.hasMore) break;
      }
    }
    for (final bridge in backgroundEligible) {
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
    const writable = <String>{'weight', 'nutrition'};
    if (signals.any((signal) => !writable.contains(signal.key))) {
      throw StateError(
        'BIL exports reviewed weight and nutrition records only.',
      );
    }
    await bridge.write(signals);
  }

  GlobalHealthSignal? _normalize(NativeHealthRecord record) {
    var value = record.value;
    var unit = record.unit;
    if (record.type == HealthDataType.weight && unit == 'lb') {
      value = value / 2.2046226218;
      unit = 'kg';
    }
    // Backward compatibility for Health Connect records imported by builds
    // that serialized SleepSessionRecord duration as seconds. The canonical
    // app contract is hours on both Android and iOS.
    if (record.type == HealthDataType.sleep && unit == 's') {
      value = value / 3600;
      unit = 'h';
    }
    final valid = switch (record.type) {
      HealthDataType.steps => unit == 'count' && value >= 0 && value <= 1000000,
      HealthDataType.distance => unit == 'm' && value >= 0 && value <= 1000000,
      HealthDataType.activeEnergy =>
        unit == 'kcal' && value >= 0 && value <= 100000,
      HealthDataType.workout => unit == 's' && value >= 0 && value <= 172800,
      HealthDataType.sleep => unit == 'h' && value >= 0 && value <= 24,
      HealthDataType.weight => unit == 'kg' && value >= 20 && value <= 500,
      _ => value.isFinite,
    };
    if (!value.isFinite || !valid) {
      return null;
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
      attributes: record.attributes,
    );
  }
}
