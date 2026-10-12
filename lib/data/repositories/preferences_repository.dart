import 'package:drift/drift.dart';

import '../database/app_database.dart';

class PreferencesRepository {
  PreferencesRepository(this._database);

  final AppDatabase _database;

  String? get localOwnerId => _database.localOwnerId;

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
  Future<String> update(
    String key,
    String Function(String? current) derive, {
    bool Function()? isCurrent,
  }) {
    if (key.trim().isEmpty) throw ArgumentError.value(key);
    return _database.transaction(() async {
      if (isCurrent?.call() == false) {
        throw StateError('preference_owner_changed');
      }
      final current = await get(key);
      if (isCurrent?.call() == false) {
        throw StateError('preference_owner_changed');
      }
      final next = derive(current);
      await set(key, next);
      if (isCurrent?.call() == false) {
        throw StateError('preference_owner_changed');
      }
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
    await _database.transaction(() => removeManyInCurrentTransaction(values));
  }

  /// Removes a preference snapshot when the caller already owns the database
  /// transaction. This is the deletion counterpart of
  /// [setManyInCurrentTransaction].
  Future<void> removeManyInCurrentTransaction(Iterable<String> keys) async {
    final values = keys.toSet();
    if (values.isEmpty) return;
    await (_database.delete(
      _database.preferences,
    )..where((item) => item.key.isIn(values))).go();
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

  Stream<Map<String, String>> watchSnapshot(Iterable<String> keys) {
    final selected = keys.toSet().toList(growable: false);
    return (_database.select(_database.preferences)
          ..where((row) => row.key.isIn(selected)))
        .watch()
        .map((rows) => {for (final row in rows) row.key: row.value});
  }

  Stream<String?> watch(String key) {
    return (_database.select(_database.preferences)
          ..where((item) => item.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  /// Commits a remote result only if no local edit replaced its input snapshot.
  Future<bool> mutateIfUnchanged({
    required Map<String, String?> expected,
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
    bool Function()? isCurrent,
  }) => _database.transaction(() async {
    void checkOwner() {
      if (isCurrent?.call() == false) {
        throw StateError('preference_owner_changed');
      }
    }

    checkOwner();
    for (final entry in expected.entries) {
      final current = await get(entry.key);
      checkOwner();
      if (current != entry.value) return false;
    }
    await setManyInCurrentTransaction(set);
    checkOwner();
    await removeManyInCurrentTransaction(remove.toSet()..removeAll(set.keys));
    checkOwner();
    return true;
  });
}
