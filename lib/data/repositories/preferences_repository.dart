import 'package:drift/drift.dart';

import '../database/app_database.dart';

class PreferencesRepository {
  PreferencesRepository(this._database);

  final AppDatabase _database;

  Future<String?> get(String key) async {
    final row = await (_database.select(
      _database.preferences,
    )..where((item) => item.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) {
    return _database
        .into(_database.preferences)
        .insertOnConflictUpdate(
          PreferencesCompanion.insert(
            key: key,
            value: value,
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> remove(String key) async {
    await (_database.delete(
      _database.preferences,
    )..where((item) => item.key.equals(key))).go();
  }

  /// Atomically derives and persists one preference from its latest value.
  Future<String> update(String key, String Function(String? current) derive) {
    if (key.trim().isEmpty) throw ArgumentError.value(key);
    return _database.transaction(() async {
      final current = await get(key);
      final next = derive(current);
      await set(key, next);
      return next;
    });
  }

  Future<void> setMany(Map<String, String> values) async {
    if (values.isEmpty) return;
    await _database.transaction(() => setManyInCurrentTransaction(values));
  }

  /// Writes a preference snapshot when the caller already owns the database
  /// transaction. Calling [setMany] from inside another transaction can wait
  /// on itself, so cross-repository atomic workflows use this explicit form.
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    if (values.isEmpty) return;
    final updatedAt = DateTime.now();
    for (final entry in values.entries) {
      if (entry.key.trim().isEmpty) throw ArgumentError.value(entry.key);
      await _database
          .into(_database.preferences)
          .insertOnConflictUpdate(
            PreferencesCompanion.insert(
              key: entry.key,
              value: entry.value,
              updatedAt: Value(updatedAt),
            ),
          );
    }
  }

  Future<void> removeMany(Iterable<String> keys) async {
    final values = keys.toSet();
    if (values.isEmpty) return;
    await _database.transaction(() async {
      await (_database.delete(
        _database.preferences,
      )..where((item) => item.key.isIn(values))).go();
    });
  }

  /// Applies a preference snapshot as one database transaction.
  ///
  /// This is used when several keys represent one durable state machine: a
  /// reader can observe either the old snapshot or the new snapshot, never a
  /// partially updated mixture.
  Future<void> mutate({
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
  }) async {
    final removals = remove.toSet()..removeAll(set.keys);
    if (set.isEmpty && removals.isEmpty) return;
    await _database.transaction(() async {
      final updatedAt = DateTime.now();
      for (final entry in set.entries) {
        if (entry.key.trim().isEmpty) throw ArgumentError.value(entry.key);
        await _database
            .into(_database.preferences)
            .insertOnConflictUpdate(
              PreferencesCompanion.insert(
                key: entry.key,
                value: entry.value,
                updatedAt: Value(updatedAt),
              ),
            );
      }
      if (removals.isNotEmpty) {
        await (_database.delete(
          _database.preferences,
        )..where((item) => item.key.isIn(removals))).go();
      }
    });
  }

  Stream<String?> watch(String key) {
    return (_database.select(_database.preferences)
          ..where((item) => item.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }
}
