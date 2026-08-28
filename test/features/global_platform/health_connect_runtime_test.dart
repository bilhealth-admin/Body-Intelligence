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
