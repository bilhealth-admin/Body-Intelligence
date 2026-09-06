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

  /// Canonical native read-capability contract used by both the runtime and
  /// every consumer-facing connection surface. Keeping this derived from
  /// [read] prevents the UI from advertising a stale subset of HealthKit or
  /// Health Connect data types.
  static final Set<String> readTypeNames = Set<String>.unmodifiable(
    read.map((type) => type.name),
  );

  /// Logical types implemented by the Android Health Connect bridge.
  ///
  /// Several nutrition values share Health Connect's single NutritionRecord
  /// permission and native record, but are emitted as separate canonical BIL
  /// signals. Every other entry has a matching native record serializer and
  /// manifest permission; clinical types remain deliberately excluded.
  static const Set<String> healthConnectReadTypeNames = <String>{
    'steps',
    'distance',
    'activeEnergy',
    'workout',
    'sleep',
    'weight',
    'bodyFat',
    'leanMass',
    'heartRate',
    'restingHeartRate',
    'hrv',
    'water',
    'nutrition',
    'nutritionProtein',
    'nutritionCarbohydrates',
    'nutritionFat',
    'nutritionFiber',
    'nutritionSugar',
    'nutritionSodium',
    'nutritionPotassium',
  };

  static Set<String> get appleHealthReadTypeNames => readTypeNames;

  static const Set<HealthDataType> write = <HealthDataType>{
    HealthDataType.weight,
    HealthDataType.nutrition,
  };

  /// Native write types implemented and disclosed by each mobile bridge.
  /// HealthKit currently exports reviewed weight records only; Android Health
  /// Connect additionally supports the reviewed nutrition export pipeline.
  static const Set<String> appleHealthWriteTypeNames = <String>{'weight'};
  static const Set<String> healthConnectWriteTypeNames = <String>{
    'weight',
    'nutrition',
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
      // Garmin's Body Battery is a fitness-readiness score. Keep both the
      // provider key and its canonical BIL key so normalization cannot be
      // discarded before or after the provider mapping is applied.
      'bodybattery',
      'recoveryscore',
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
    this.changesTokenExpired = false,
  });
  final List<NativeHealthRecord> records;
  final List<String> deletedIds;
  final String? nextAnchor;
  final bool hasMore;

  /// Health Connect could no longer serve the supplied changes token.
  ///
  /// The caller must discard that token and perform a bounded bootstrap read
  /// with a newly issued token. HealthKit and other bridges leave this false.
  final bool changesTokenExpired;
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
      // HealthKit intentionally does not expose read authorization state.
      // `HKHealthStore.authorizationStatus(for:)` describes sharing/write
      // access, so using that value to gate a read query can incorrectly
      // produce an empty allow-list even after the user enabled Apple Health
      // reads. The query itself is the authority: denied read types simply
      // return no records. Android/other providers retain their explicit
      // permission filtering.
      final appleHealthReadStateIsIndeterminate = _isAppleHealthBridge(bridge);
      final allowed = appleHealthReadStateIsIndeterminate
          ? requestedTypes.map((type) => type.name).toSet()
          : requestedTypes
                .where((type) => permission[type.name] == true)
                .map((e) => e.name)
                .toSet();
      if (allowed.isEmpty) continue;
      // The native change token belongs to the exact record-type set queried,
      // not merely to what the caller requested. On Health Connect a user can
      // grant only part of the requested permissions and grant another type
      // later. Reusing the old subset's token would skip that newly granted
      // type's history, so reset the anchor whenever the effective permission
      // scope changes.
      // Native bridges may expose non-record permission markers whose state
      // changes the meaning of an anchor. Health Connect history access is the
      // first such marker: granting it later expands a bootstrap from 30 to
      // 365 days even when the selected record types are unchanged.
      final anchorScopeMarkers = permission.entries
          .where((entry) => entry.key.startsWith('__') && entry.value)
          .map((entry) => entry.key);
      final allowedScopeSignature = (<String>{
        ...allowed,
        ...anchorScopeMarkers,
      }.toList()..sort()).join(',');
      final anchorState = await store.get('health_anchor', bridge.id);
      final anchor =
          anchorState != null && anchorState['scope'] == allowedScopeSignature
          ? anchorState['anchor'] as String?
          : null;
      var nextAnchor = anchor;
      var pages = 0;
      var expiredTokenRecoveryAttempted = false;
      while (pages < pageLimit) {
        final page = await bridge.readChanges(
          anchor: nextAnchor,
          asOf: asOf,
          types: allowed,
        );
        if (page.changesTokenExpired) {
          // Health Connect change tokens expire (and may be invalidated by the
          // provider). Never persist the response's unusable next token. Drop
          // the durable anchor and request one bounded bootstrap exactly once;
          // health_seen then de-duplicates the historical snapshot by stable
          // provider/record/type identity while preserving provenance.
          await store.remove('health_anchor', bridge.id);
          if (nextAnchor != null && !expiredTokenRecoveryAttempted) {
            expiredTokenRecoveryAttempted = true;
            nextAnchor = null;
            await audit.record(
              GlobalAuditEvent(
                action: 'health.anchor.bootstrap_recovery',
                subjectId: bridge.id,
                at: asOf,
                metadata: <String, Object?>{
                  'reason': 'changes_token_expired',
                  'scope': allowedScopeSignature,
                },
              ),
            );
            continue;
          }
          await audit.record(
            GlobalAuditEvent(
              action: 'health.anchor.bootstrap_failed',
              subjectId: bridge.id,
              at: asOf,
              metadata: <String, Object?>{
                'reason': 'changes_token_expired',
                'scope': allowedScopeSignature,
              },
            ),
          );
          break;
        }
        pages++;
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
        // An UpsertionChange replaces the whole native series. Purge any
        // persisted children before writing its current samples so shortening
        // or editing a series cannot leave stale measurements behind.
        final replacedRecordFamilies = <String>{
          ...page.deletedIds,
          for (final record in page.records)
            if (record.attributes['parentRecordId'] case final String parentId)
              parentId,
        };
        // Scan the persisted bucket once for the entire page. A page may hold
        // hundreds of HeartRateRecord series; scanning once per parent would
        // otherwise turn synchronization into O(parents x stored signals).
        await _removePersistedRecordFamilies(bridge.id, replacedRecordFamilies);
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
          'scope': allowedScopeSignature,
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
      HealthDataType.bodyFat => unit == '%' && value >= 0 && value <= 100,
      HealthDataType.leanMass => unit == 'kg' && value >= 0 && value <= 500,
      HealthDataType.heartRate || HealthDataType.restingHeartRate =>
        unit == 'count/min' && value >= 20 && value <= 300,
      HealthDataType.hrv => unit == 'ms' && value >= 0 && value <= 10000,
      HealthDataType.water => unit == 'mL' && value >= 0 && value <= 100000,
      HealthDataType.nutrition =>
        unit == 'kcal' && value >= 0 && value <= 100000,
      HealthDataType.nutritionProtein ||
      HealthDataType.nutritionCarbohydrates ||
      HealthDataType.nutritionFat ||
      HealthDataType.nutritionFiber ||
      HealthDataType.nutritionSugar =>
        unit == 'g' && value >= 0 && value <= 100000,
      HealthDataType.nutritionSodium || HealthDataType.nutritionPotassium =>
        unit == 'mg' && value >= 0 && value <= 1000000,
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

  Future<void> _removePersistedRecordFamilies(
    String providerId,
    Set<String> parentRecordIds,
  ) async {
    if (parentRecordIds.isEmpty) return;
    for (final row in await store.list('health_signals')) {
      if (row['providerId'] != providerId) continue;
      final recordId = row['recordId'];
      final attributes = row['attributes'] as Map?;
      if (!parentRecordIds.contains(recordId) &&
          !parentRecordIds.contains(attributes?['parentRecordId'])) {
        continue;
      }
      final key = row['key'];
      if (recordId is! String || key is! String) continue;
      final identity = '$providerId:$recordId:$key';
      await store.remove('health_signals', identity);
      await store.remove('health_seen', identity);
    }
    // Preserve backward compatibility for pre-series records even when they
    // are absent from health_signals but still have a health_seen fingerprint.
    for (final parentRecordId in parentRecordIds) {
      for (final type in BilHealthScope.read) {
        final identity = '$providerId:$parentRecordId:${type.name}';
        await store.remove('health_signals', identity);
        await store.remove('health_seen', identity);
      }
    }
  }

  bool _isAppleHealthBridge(NativeHealthBridge bridge) {
    final id = bridge.id.toLowerCase();
    return id.contains('apple') || id.contains('healthkit');
  }
}
