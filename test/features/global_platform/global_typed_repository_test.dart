import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/persistence/global_platform_sqlite_store.dart';
import 'package:body_intelligence_log/features/global_platform/persistence/global_typed_repositories.dart';

void main() {
  test(
    'typed SQLite repository enforces CAS, indexing, retention and integrity',
    () async {
      final store = SqliteGlobalPlatformStore.memory();
      final repository = GlobalTypedRepository(
        store: store,
        bucket: 'b',
        schemaVersion: 2,
        largePayloadLimitBytes: 128,
      );
      final first = await repository.upsert('x', <String, Object?>{
        'id': 'x',
        'value': 1,
      });
      expect(first.revision, 1);
      await expectLater(
        repository.upsert('x', <String, Object?>{
          'id': 'x',
          'value': 2,
        }, expectedRevision: 0),
        throwsStateError,
      );
      await repository.upsert('y', <String, Object?>{'id': 'y', 'value': 2});
      await store.verifyIntegrity();
      await store.retain(
        'b',
        oldestAllowed: DateTime.utc(2000),
        maximumRecords: 1,
      );
      expect((await store.list('b')).length, 1);
      store.close();
    },
  );
}
