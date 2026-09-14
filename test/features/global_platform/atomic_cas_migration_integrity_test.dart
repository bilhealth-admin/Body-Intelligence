import 'dart:async';

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
  test(
    'paged SQLite reads preserve ordering and yield between pages',
    () async {
      final s = SqliteGlobalPlatformStore.memory();
      addTearDown(s.close);
      final updatedAt = DateTime.utc(2026, 9, 13, 20).toIso8601String();
      for (var index = 0; index < 130; index++) {
        await s.put(
          'health_signals',
          'signal-${index.toString().padLeft(3, '0')}',
          {'id': index, 'updatedAt': updatedAt},
        );
      }

      var completed = false;
      var uiTurnObservedBeforeCompletion = false;
      Timer.run(() {
        uiTurnObservedBeforeCompletion = !completed;
      });

      final rows = await s
          .list('health_signals')
          .whenComplete(() => completed = true);

      expect(rows, hasLength(130));
      expect(
        rows.map((row) => row['id']).toList(),
        List<int>.generate(130, (index) => index),
      );
      expect(uiTurnObservedBeforeCompletion, isTrue);
    },
  );

  test('paged updated-after query preserves its exclusive boundary', () async {
    final s = SqliteGlobalPlatformStore.memory();
    addTearDown(s.close);
    final boundary = DateTime.utc(2026, 9, 13, 20);
    await s.put('health_signals', 'before', {
      'id': -1,
      'updatedAt': boundary
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
    });
    await s.put('health_signals', 'boundary', {
      'id': 0,
      'updatedAt': boundary.toIso8601String(),
    });
    for (var index = 1; index <= 130; index++) {
      await s.put(
        'health_signals',
        'after-${index.toString().padLeft(3, '0')}',
        {
          'id': index,
          'updatedAt': boundary.add(Duration(seconds: index)).toIso8601String(),
        },
      );
    }

    final rows = await s.queryUpdatedAfter('health_signals', boundary);

    expect(rows, hasLength(130));
    expect(rows.first['id'], 1);
    expect(rows.last['id'], 130);
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
