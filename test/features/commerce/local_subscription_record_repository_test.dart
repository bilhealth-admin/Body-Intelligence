import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_record.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_snapshot.dart';
import 'package:body_intelligence_log/features/commerce/repositories/local_subscription_record_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryStore implements CommerceKeyValueStore {
  final values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  void remove(String key) => values.remove(key);

  @override
  void write(String key, String value) => values[key] = value;
}

void main() {
  final now = DateTime.utc(2026, 7, 24, 12);

  SubscriptionSnapshot snapshot() => SubscriptionSnapshot(
    record: SubscriptionRecord(
      plan: CommercePlan.elite,
      lifecycle: SubscriptionLifecycle.gracePeriod,
      authorityVerified: true,
      provider: SubscriptionProvider.google,
      startedAt: now.subtract(const Duration(days: 30)),
      currentPeriodEndsAt: now.subtract(const Duration(days: 1)),
      gracePeriodEndsAt: now.add(const Duration(days: 2)),
    ),
    verifiedAt: now.subtract(const Duration(hours: 1)),
    persistedAt: now,
  );

  test('verified snapshot round-trips deterministically', () {
    final store = _MemoryStore();
    final repository = LocalSubscriptionRecordRepository(store);

    repository.write(snapshot());
    final restored = repository.read();

    expect(restored, isNotNull);
    expect(restored!.record.plan, CommercePlan.elite);
    expect(restored.record.lifecycle, SubscriptionLifecycle.gracePeriod);
    expect(restored.record.provider, SubscriptionProvider.google);
    expect(restored.record.authorityVerified, isTrue);
    expect(restored.verifiedAt, now.subtract(const Duration(hours: 1)));
    expect(restored.persistedAt, now);
  });

  test('corrupt cache is cleared and never grants authority', () {
    final store = _MemoryStore()
      ..values[LocalSubscriptionRecordRepository.storageKey] = 'invalid';
    final repository = LocalSubscriptionRecordRepository(store);

    expect(repository.read(), isNull);
    expect(store.values, isEmpty);
  });

  test('unverified records cannot be persisted as snapshots', () {
    expect(
      () => SubscriptionSnapshot(
        record: SubscriptionRecord(
          plan: CommercePlan.pro,
          lifecycle: SubscriptionLifecycle.active,
          authorityVerified: false,
          provider: SubscriptionProvider.web,
          currentPeriodEndsAt: now.add(const Duration(days: 1)),
        ),
        verifiedAt: now,
        persistedAt: now,
      ),
      throwsArgumentError,
    );
  });
}
