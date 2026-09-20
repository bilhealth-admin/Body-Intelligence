import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/persistence/global_platform_sqlite_store.dart';

void main() {
  test('atomic CAS permits one writer and rejects stale revision', () async {
    final s = SqliteGlobalPlatformStore.memory();
    await s.put('b', 'k', {
      'version': 1,
      'revision': 1,
      'payload': {'v': 1},
      'checksum': 'x',
      'updatedAt': DateTime.utc(2026).toIso8601String(),
    });
    final a = s.compareAndSwap(
      bucket: 'b',
      key: 'k',
      expectedRevision: 1,
      nextValue: {
        'version': 1,
        'revision': 2,
        'payload': {'v': 2},
        'checksum': 'x',
      },
    );
    final b = s.compareAndSwap(
      bucket: 'b',
      key: 'k',
      expectedRevision: 1,
      nextValue: {
        'version': 1,
        'revision': 2,
        'payload': {'v': 3},
        'checksum': 'x',
      },
    );
    final results = await Future.wait([
      a.then((_) => true).catchError((_) => false),
      b.then((_) => true).catchError((_) => false),
    ]);
    expect(results.where((x) => x).length, 1);
    s.close();
  });
  test('migration is idempotent and checksum guarded', () async {
    final s = SqliteGlobalPlatformStore.memory();
    await s.applyMigration(
      id: 1,
      checksum: 'abc',
      statements: ['CREATE TABLE r10_test(id INTEGER PRIMARY KEY)'],
    );
    await s.applyMigration(
      id: 1,
      checksum: 'abc',
      statements: ['CREATE TABLE r10_test(id INTEGER PRIMARY KEY)'],
    );
    expect(
      () => s.applyMigration(id: 1, checksum: 'different', statements: []),
      throwsStateError,
    );
    s.close();
  });
}
