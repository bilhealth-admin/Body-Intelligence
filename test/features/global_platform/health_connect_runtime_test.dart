import 'global_platform_test_support.dart';

void main() {
  test('health runtime blocks access without consent', () async {
    final out =
        await UnifiedHealthDataRuntime(
          bridges: [TestHealthBridge()],
          store: InMemoryGlobalStore(),
          audit: InMemoryGlobalAuditSink(),
        ).synchronize(
          asOf: DateTime.utc(2026),
          consent: GlobalConsentGrant(
            scope: 'health',
            state: GlobalConsentState.denied,
            updatedAt: DateTime.utc(2026),
          ),
        );
    expect(out, isEmpty);
  });

  test(
    'legacy Health Connect sleep seconds normalize to canonical hours',
    () async {
      final asOf = DateTime.utc(2026, 8, 23, 8);
      final output =
          await UnifiedHealthDataRuntime(
            bridges: [_LegacySleepBridge(asOf)],
            store: InMemoryGlobalStore(),
            audit: InMemoryGlobalAuditSink(),
          ).synchronize(
            asOf: asOf,
            consent: GlobalConsentGrant(
              scope: 'health',
              state: GlobalConsentState.granted,
              updatedAt: asOf,
            ),
            types: const {HealthDataType.sleep},
          );

      expect(output, hasLength(1));
      expect(output.single.key, 'sleep');
      expect(output.single.canonicalValue, 7.5);
      expect(output.single.canonicalUnit, 'h');
      expect(output.single.attributes['endedAt'], isNotNull);
    },
  );

  test(
    'extended Health Connect signals keep provenance and reject wrong units',
    () async {
      final asOf = DateTime.utc(2026, 9, 4, 10);
      final audit = InMemoryGlobalAuditSink();
      final output =
          await UnifiedHealthDataRuntime(
            bridges: [_ExtendedHealthConnectBridge(asOf)],
            store: InMemoryGlobalStore(),
            audit: audit,
          ).synchronize(
            asOf: asOf,
            consent: GlobalConsentGrant(
              scope: 'health',
              state: GlobalConsentState.granted,
              updatedAt: asOf,
            ),
            types: const {
              HealthDataType.water,
              HealthDataType.bodyFat,
              HealthDataType.nutritionProtein,
            },
          );

      expect(output.map((signal) => signal.key).toSet(), {
        'water',
        'bodyFat',
        'nutritionProtein',
      });
      expect(
        output.every(
          (signal) =>
              signal.provenance.providerId == 'android-health-connect' &&
              signal.provenance.sourceId == 'com.example.health.source' &&
              signal.provenance.deviceId == 'watch-model',
        ),
        isTrue,
      );
      expect(
        audit.events
            .where((event) => event.action == 'health.record.rejected')
            .single
            .metadata['reason'],
        'invalid_value_or_unit',
      );
    },
  );

  test(
    'Health Connect resets its anchor when newly granted types expand scope',
    () async {
      final asOf = DateTime.utc(2026, 9, 4, 12);
      final bridge = _PermissionChangingHealthConnectBridge();
      final store = InMemoryGlobalStore();
      final runtime = UnifiedHealthDataRuntime(
        bridges: [bridge],
        store: store,
        audit: InMemoryGlobalAuditSink(),
      );
      final consent = GlobalConsentGrant(
        scope: 'health',
        state: GlobalConsentState.granted,
        updatedAt: asOf,
      );

      await runtime.synchronize(
        asOf: asOf,
        consent: consent,
        types: const {HealthDataType.weight, HealthDataType.heartRate},
      );
      expect(bridge.receivedAnchors, [isNull]);
      expect(bridge.receivedTypes.single, {'weight'});
      expect((await store.get('health_anchor', bridge.id))?['scope'], 'weight');

      bridge.grantedTypes.add('heartRate');
      await runtime.synchronize(
        asOf: asOf.add(const Duration(minutes: 1)),
        consent: consent,
        types: const {HealthDataType.weight, HealthDataType.heartRate},
      );

      expect(bridge.receivedAnchors, [isNull, isNull]);
      expect(bridge.receivedTypes.last, {'heartRate', 'weight'});
      expect(
        (await store.get('health_anchor', bridge.id))?['scope'],
        'heartRate,weight',
      );
    },
  );

  test(
    'Health Connect resets its anchor when history access changes scope',
    () async {
      final asOf = DateTime.utc(2026, 9, 4, 13);
      final bridge = _PermissionChangingHealthConnectBridge();
      final store = InMemoryGlobalStore();
      final runtime = UnifiedHealthDataRuntime(
        bridges: [bridge],
        store: store,
        audit: InMemoryGlobalAuditSink(),
      );
      final consent = GlobalConsentGrant(
        scope: 'health',
        state: GlobalConsentState.granted,
        updatedAt: asOf,
      );

      await runtime.synchronize(
        asOf: asOf,
        consent: consent,
        types: const {HealthDataType.weight},
      );
      expect(bridge.receivedAnchors, [isNull]);

      bridge.historyPermissionGranted = true;
      await runtime.synchronize(
        asOf: asOf.add(const Duration(minutes: 1)),
        consent: consent,
        types: const {HealthDataType.weight},
      );

      expect(bridge.receivedAnchors, [isNull, isNull]);
      expect(
        (await store.get('health_anchor', bridge.id))?['scope'],
        '__readHealthDataHistory,weight',
      );
    },
  );

  test(
    'heart-rate series upsert replaces stale children and deletion removes all',
    () async {
      final asOf = DateTime.utc(2026, 9, 4, 14);
      final bridge = _HeartRateSeriesHealthConnectBridge(asOf);
      final store = InMemoryGlobalStore();
      final runtime = UnifiedHealthDataRuntime(
        bridges: [bridge],
        store: store,
        audit: InMemoryGlobalAuditSink(),
      );
      final consent = GlobalConsentGrant(
        scope: 'health',
        state: GlobalConsentState.granted,
        updatedAt: asOf,
      );

      await runtime.synchronize(
        asOf: asOf,
        consent: consent,
        types: const {HealthDataType.heartRate},
      );
      expect(await store.list('health_signals'), hasLength(2));

      await runtime.synchronize(
        asOf: asOf.add(const Duration(minutes: 1)),
        consent: consent,
        types: const {HealthDataType.heartRate},
      );
      final replaced = await store.list('health_signals');
      expect(replaced, hasLength(1));
      expect(replaced.single['recordId'], 'series-1#heartRate#1#0');
      expect(replaced.single['canonicalValue'], 73.0);

      await runtime.synchronize(
        asOf: asOf.add(const Duration(minutes: 2)),
        consent: consent,
        types: const {HealthDataType.heartRate},
      );
      expect(await store.list('health_signals'), isEmpty);
      expect(await store.list('health_seen'), isEmpty);
      expect(bridge.receivedAnchors, [
        isNull,
        'series-anchor-1',
        'series-anchor-2',
      ]);
    },
  );

  test(
    'expired Health Connect token bootstraps once and de-duplicates history',
    () async {
      final asOf = DateTime.utc(2026, 9, 4, 14);
      final observedAt = asOf.subtract(const Duration(days: 1));
      final bridge = _ExpiredTokenHealthConnectBridge(observedAt: observedAt);
      final store = InMemoryGlobalStore();
      final audit = InMemoryGlobalAuditSink();
      await store.put('health_anchor', bridge.id, <String, Object?>{
        'anchor': 'expired-token',
        'scope': 'weight',
      });
      await store.put(
        'health_seen',
        '${bridge.id}:stable:weight',
        <String, Object?>{
          'identity': '${bridge.id}:stable:weight',
          'fingerprint': '90.0:kg:${observedAt.toIso8601String()}:false',
          'updatedAt': asOf.subtract(const Duration(days: 1)).toIso8601String(),
        },
      );

      final output =
          await UnifiedHealthDataRuntime(
            bridges: [bridge],
            store: store,
            audit: audit,
            // The expired response is control flow, not a consumed data page.
            pageLimit: 1,
          ).synchronize(
            asOf: asOf,
            consent: GlobalConsentGrant(
              scope: 'health',
              state: GlobalConsentState.granted,
              updatedAt: asOf,
            ),
            types: const {HealthDataType.weight},
          );

      expect(bridge.receivedAnchors, ['expired-token', isNull]);
      expect(output.map((signal) => signal.provenance.recordId), ['new']);
      expect(output.single.provenance.sourceId, 'com.example.watch');
      expect(
        await store.get('health_signals', '${bridge.id}:poison:weight'),
        isNull,
        reason: 'Records attached to an expired-token response are ignored.',
      );
      expect(
        (await store.get('health_anchor', bridge.id))?['anchor'],
        'fresh-token',
      );
      expect(
        audit.events
            .where(
              (event) => event.action == 'health.anchor.bootstrap_recovery',
            )
            .length,
        1,
      );
    },
  );

  test(
    'a second expired bootstrap response stops without a retry loop',
    () async {
      final asOf = DateTime.utc(2026, 9, 4, 15);
      final bridge = _AlwaysExpiredHealthConnectBridge();
      final store = InMemoryGlobalStore();
      final audit = InMemoryGlobalAuditSink();
      await store.put('health_anchor', bridge.id, <String, Object?>{
        'anchor': 'expired-token',
        'scope': 'weight',
      });

      final output =
          await UnifiedHealthDataRuntime(
            bridges: [bridge],
            store: store,
            audit: audit,
          ).synchronize(
            asOf: asOf,
            consent: GlobalConsentGrant(
              scope: 'health',
              state: GlobalConsentState.granted,
              updatedAt: asOf,
            ),
            types: const {HealthDataType.weight},
          );

      expect(output, isEmpty);
      expect(bridge.receivedAnchors, ['expired-token', isNull]);
      expect(await store.get('health_anchor', bridge.id), isNull);
      expect(
        audit.events.map((event) => event.action),
        containsAllInOrder(<String>[
          'health.anchor.bootstrap_recovery',
          'health.anchor.bootstrap_failed',
        ]),
      );
    },
  );
}

final class _ExtendedHealthConnectBridge implements NativeHealthBridge {
  _ExtendedHealthConnectBridge(this.asOf);

  final DateTime asOf;

  @override
  String get id => 'android-health-connect';

  @override
  Future<Map<String, bool>> permissions() async => const {
    'water': true,
    'bodyFat': true,
    'nutritionProtein': true,
  };

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async => NativeHealthPage(
    records: [
      _record('water-valid', HealthDataType.water, 750, 'mL'),
      _record('body-fat-valid', HealthDataType.bodyFat, 18.5, '%'),
      _record('protein-valid', HealthDataType.nutritionProtein, 32, 'g'),
      _record('water-wrong-unit', HealthDataType.water, 0.75, 'L'),
    ],
    deletedIds: const [],
    nextAnchor: 'extended-anchor',
    hasMore: false,
  );

  NativeHealthRecord _record(
    String recordId,
    HealthDataType type,
    double value,
    String unit,
  ) => NativeHealthRecord(
    id: recordId,
    type: type,
    value: value,
    unit: unit,
    observedAt: asOf.subtract(const Duration(minutes: 10)),
    sourceId: 'com.example.health.source',
    deviceId: 'watch-model',
    confidence: 1,
    providerId: id,
    attributes: const {'wearableKind': 'wear_os_watch'},
  );

  @override
  Future<void> request(Set<String> types, {required bool write}) async {}

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}

  @override
  Future<void> delete(List<String> recordIds) async {}
}

final class _ExpiredTokenHealthConnectBridge implements NativeHealthBridge {
  _ExpiredTokenHealthConnectBridge({required this.observedAt});

  final DateTime observedAt;
  final List<String?> receivedAnchors = <String?>[];

  @override
  String get id => 'android-health-connect';

  @override
  Future<Map<String, bool>> permissions() async => const {'weight': true};

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async {
    receivedAnchors.add(anchor);
    if (anchor != null) {
      return NativeHealthPage(
        records: [_record('poison', 75)],
        deletedIds: const [],
        nextAnchor: 'unusable-token',
        hasMore: true,
        changesTokenExpired: true,
      );
    }
    return NativeHealthPage(
      records: [_record('stable', 90), _record('new', 88)],
      deletedIds: const [],
      nextAnchor: 'fresh-token',
      hasMore: false,
    );
  }

  NativeHealthRecord _record(String id, double value) => NativeHealthRecord(
    id: id,
    type: HealthDataType.weight,
    value: value,
    unit: 'kg',
    observedAt: observedAt,
    sourceId: 'com.example.watch',
    deviceId: 'watch-1',
    confidence: 1,
    providerId: this.id,
    attributes: const {'wearableKind': 'wear_os_watch'},
  );

  @override
  Future<void> request(Set<String> types, {required bool write}) async {}

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}

  @override
  Future<void> delete(List<String> recordIds) async {}
}

final class _AlwaysExpiredHealthConnectBridge implements NativeHealthBridge {
  final List<String?> receivedAnchors = <String?>[];

  @override
  String get id => 'android-health-connect';

  @override
  Future<Map<String, bool>> permissions() async => const {'weight': true};

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async {
    receivedAnchors.add(anchor);
    return const NativeHealthPage(
      records: [],
      deletedIds: [],
      nextAnchor: 'still-invalid',
      hasMore: true,
      changesTokenExpired: true,
    );
  }

  @override
  Future<void> request(Set<String> types, {required bool write}) async {}

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}

  @override
  Future<void> delete(List<String> recordIds) async {}
}

final class _PermissionChangingHealthConnectBridge
    implements NativeHealthBridge {
  final Set<String> grantedTypes = <String>{'weight'};
  bool historyPermissionGranted = false;
  final List<String?> receivedAnchors = <String?>[];
  final List<Set<String>> receivedTypes = <Set<String>>[];

  @override
  String get id => 'android-health-connect';

  @override
  Future<Map<String, bool>> permissions() async => <String, bool>{
    for (final type in grantedTypes) type: true,
    '__readHealthDataHistory': historyPermissionGranted,
  };

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async {
    receivedAnchors.add(anchor);
    receivedTypes.add(Set<String>.from(types));
    return NativeHealthPage(
      records: const [],
      deletedIds: const [],
      nextAnchor: 'anchor-${receivedAnchors.length}',
      hasMore: false,
    );
  }

  @override
  Future<void> request(Set<String> types, {required bool write}) async {}

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}

  @override
  Future<void> delete(List<String> recordIds) async {}
}

final class _HeartRateSeriesHealthConnectBridge implements NativeHealthBridge {
  _HeartRateSeriesHealthConnectBridge(this.asOf);

  final DateTime asOf;
  final List<String?> receivedAnchors = <String?>[];
  var calls = 0;

  @override
  String get id => 'android-health-connect';

  @override
  Future<Map<String, bool>> permissions() async => const {'heartRate': true};

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async {
    receivedAnchors.add(anchor);
    calls += 1;
    if (calls == 1) {
      return NativeHealthPage(
        records: [_sample(0, 70), _sample(1, 72)],
        deletedIds: const [],
        nextAnchor: 'series-anchor-1',
        hasMore: false,
      );
    }
    if (calls == 2) {
      return NativeHealthPage(
        records: [_sample(0, 73)],
        deletedIds: const [],
        nextAnchor: 'series-anchor-2',
        hasMore: false,
      );
    }
    return const NativeHealthPage(
      records: [],
      deletedIds: ['series-1'],
      nextAnchor: 'series-anchor-3',
      hasMore: false,
    );
  }

  NativeHealthRecord _sample(int index, double value) => NativeHealthRecord(
    id: 'series-1#heartRate#${index + 1}#$index',
    type: HealthDataType.heartRate,
    value: value,
    unit: 'count/min',
    observedAt: asOf.subtract(Duration(minutes: 2 - index)),
    sourceId: 'com.example.watch',
    deviceId: 'watch-1',
    confidence: 1,
    providerId: id,
    attributes: {'parentRecordId': 'series-1', 'seriesSampleIndex': index},
  );

  @override
  Future<void> request(Set<String> types, {required bool write}) async {}

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}

  @override
  Future<void> delete(List<String> recordIds) async {}
}

final class _LegacySleepBridge implements NativeHealthBridge {
  _LegacySleepBridge(this.asOf);

  final DateTime asOf;

  @override
  String get id => 'android-health-connect';

  @override
  Future<Map<String, bool>> permissions() async => const {'sleep': true};

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async => NativeHealthPage(
    records: [
      NativeHealthRecord(
        id: 'sleep-session-1',
        type: HealthDataType.sleep,
        value: 27000,
        unit: 's',
        observedAt: this.asOf.subtract(const Duration(hours: 8)),
        sourceId: 'com.example.watch',
        deviceId: 'watch-1',
        confidence: 1,
        providerId: id,
        timeZoneId: '+02:00',
        attributes: {
          'endedAt': this.asOf
              .subtract(const Duration(minutes: 30))
              .toIso8601String(),
          'stages': const <Object?>[],
        },
      ),
    ],
    deletedIds: const [],
    nextAnchor: 'sleep-anchor',
    hasMore: false,
  );

  @override
  Future<void> request(Set<String> types, {required bool write}) async {}

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}

  @override
  Future<void> delete(List<String> recordIds) async {}
}
