import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_tombstone_index.dart';

class _CountingStore implements GlobalDurableStore {
  final inner = InMemoryGlobalStore();
  int lists = 0;
  int gets = 0;
  @override
  Future<List<Map<String, Object?>>> list(String bucket) { lists++; return inner.list(bucket); }
  @override
  Future<Map<String, Object?>?> get(String bucket, String key) { gets++; return inner.get(bucket, key); }
  @override
  Future<void> put(String bucket, String key, Map<String, Object?> value) => inner.put(bucket, key, value);
  @override
  Future<void> remove(String bucket, String key) => inner.remove(bucket, key);
  @override
  Future<void> clear(String bucket) => inner.clear(bucket);
}

void main() {
  test('a thousand contributing IDs require one modern tombstone scan and no point reads', () async {
    final store = _CountingStore();
    await store.put('health_tombstones', 'native:gone', {'provider':'native','recordId':'gone'});
    final index = await ConnectedHealthTombstoneIndex.load(store);
    expect(await index.containsAny(List.generate(1000, (i) => 'native:kept$i')), isFalse);
    expect(await index.containsAny(['native:child', 'native:gone']), isTrue);
    expect(store.lists, 1);
    expect(store.gets, 0);
  });
  test('legacy value-only tombstones still invalidate a cached parent or source sample', () async {
    final store = _CountingStore();
    await store.put('health_tombstones', 'native:parent', {'deleted':true});
    final index = await ConnectedHealthTombstoneIndex.load(store);
    expect(await index.containsAny(['native:child','native:parent']), isTrue);
    final reads = store.gets;
    expect(await index.containsAny(['native:child','native:parent']), isTrue);
    expect(store.gets, reads, reason:'negative and positive legacy reads are memoized for this projection');
    expect(await store.inner.get('health_tombstones','native:parent'), {'deleted':true});
  });
  test('a new projection sees a deletion arriving after an earlier snapshot', () async {
    final store = _CountingStore();
    final before = await ConnectedHealthTombstoneIndex.load(store);
    expect(await before.containsAny(['native:sample']), isFalse);
    await store.put('health_tombstones','native:sample', {'provider':'native','recordId':'sample'});
    final after = await ConnectedHealthTombstoneIndex.load(store);
    expect(await after.containsAny(['native:sample']), isTrue);
    expect(await after.containsAny(['other:sample']), isFalse);
  });
}
