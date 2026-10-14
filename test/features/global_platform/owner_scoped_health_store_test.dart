import 'dart:async';

import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/persistence/owner_scoped_health_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'health cache, consent, and evidence are isolated A to B to A',
    () async {
      final inner = InMemoryGlobalStore();
      var activeOwner = 'owner-a';
      final ownerA = OwnerScopedHealthStore(
        inner: inner,
        ownerId: 'owner-a',
        readCurrentOwnerId: () => activeOwner,
      );
      await ownerA.put('connected_health_consent', 'Apple Health', {
        'readRequested': true,
      });
      await ownerA.put('connected_health_ui', 'snapshot', {
        'signals': [
          {'key': 'weight', 'value': 81.5},
        ],
      });
      await ownerA.put('health_anchor', 'apple-health', {'anchor': 'a1'});

      activeOwner = 'owner-b';
      final ownerB = OwnerScopedHealthStore(
        inner: inner,
        ownerId: 'owner-b',
        readCurrentOwnerId: () => activeOwner,
      );
      expect(
        await ownerB.get('connected_health_consent', 'Apple Health'),
        isNull,
      );
      expect(await ownerB.get('connected_health_ui', 'snapshot'), isNull);
      expect(await ownerB.list('health_signals'), isEmpty);
      await ownerB.put('connected_health_ui', 'snapshot', {
        'signals': [
          {'key': 'steps', 'value': 900},
        ],
      });

      activeOwner = 'owner-a';
      expect(
        (await ownerA.get('connected_health_ui', 'snapshot'))!['signals'],
        [
          {'key': 'weight', 'value': 81.5},
        ],
      );
      expect(await ownerA.get('health_anchor', 'apple-health'), {
        'anchor': 'a1',
      });
      await expectLater(
        ownerB.get('connected_health_ui', 'snapshot'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('unknown-owner legacy rows remain preserved but inaccessible', () async {
    final inner = InMemoryGlobalStore();
    await inner.put('connected_health_ui', 'snapshot', {
      'signals': [
        {'key': 'weight', 'value': 81.5},
      ],
    });
    const owner = OwnerScopedHealthStore.localDeviceOwner;
    final scoped = OwnerScopedHealthStore(
      inner: inner,
      ownerId: owner,
      readCurrentOwnerId: () => owner,
    );

    expect(await scoped.get('connected_health_ui', 'snapshot'), isNull);
    expect(await inner.get('connected_health_ui', 'snapshot'), isNotNull);
  });

  test('account deletion clears only that owner’s BIL health cache', () async {
    final inner = InMemoryGlobalStore();
    var activeOwner = 'owner-a';
    final ownerA = OwnerScopedHealthStore(
      inner: inner,
      ownerId: 'owner-a',
      readCurrentOwnerId: () => activeOwner,
    );
    final ownerB = OwnerScopedHealthStore(
      inner: inner,
      ownerId: 'owner-b',
      readCurrentOwnerId: () => activeOwner,
    );

    for (final bucket in OwnerScopedHealthStore.accountHealthDataBuckets) {
      await ownerA.put(bucket, 'row', {'owner': 'a'});
    }
    activeOwner = 'owner-b';
    for (final bucket in OwnerScopedHealthStore.accountHealthDataBuckets) {
      await ownerB.put(bucket, 'row', {'owner': 'b'});
    }
    await inner.put('connected_health_ui', 'legacy', {'owner': 'unknown'});

    activeOwner = 'owner-a';
    await ownerA.clearForAccountDeletion();
    for (final bucket in OwnerScopedHealthStore.accountHealthDataBuckets) {
      expect(await ownerA.get(bucket, 'row'), isNull, reason: bucket);
    }

    activeOwner = 'owner-b';
    for (final bucket in OwnerScopedHealthStore.accountHealthDataBuckets) {
      expect(await ownerB.get(bucket, 'row'), {'owner': 'b'}, reason: bucket);
    }
    expect(await inner.get('connected_health_ui', 'legacy'), {
      'owner': 'unknown',
    });
  });

  test(
    'a read finishing after logout cannot return the prior owner cache',
    () async {
      final inner = _DelayedReadStore();
      var activeOwner = 'owner-a';
      final scoped = OwnerScopedHealthStore(
        inner: inner,
        ownerId: 'owner-a',
        readCurrentOwnerId: () => activeOwner,
      );
      await scoped.put('connected_health_ui', 'snapshot', {'value': 81.5});

      final pendingRead = scoped.get('connected_health_ui', 'snapshot');
      await inner.readStarted.future;
      activeOwner = OwnerScopedHealthStore.localDeviceOwner;
      inner.releaseRead.complete();

      await expectLater(pendingRead, throwsA(isA<StateError>()));
    },
  );
}

final class _DelayedReadStore implements GlobalDurableStore {
  final InMemoryGlobalStore _inner = InMemoryGlobalStore();
  final Completer<void> readStarted = Completer<void>();
  final Completer<void> releaseRead = Completer<void>();

  @override
  Future<void> put(String bucket, String key, Map<String, Object?> value) =>
      _inner.put(bucket, key, value);

  @override
  Future<Map<String, Object?>?> get(String bucket, String key) async {
    final value = await _inner.get(bucket, key);
    if (!readStarted.isCompleted) readStarted.complete();
    await releaseRead.future;
    return value;
  }

  @override
  Future<List<Map<String, Object?>>> list(String bucket) => _inner.list(bucket);

  @override
  Future<void> remove(String bucket, String key) => _inner.remove(bucket, key);

  @override
  Future<void> clear(String bucket) => _inner.clear(bucket);
}
