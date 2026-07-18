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

  Stream<String?> watch(String key) {
    return (_database.select(_database.preferences)
          ..where((item) => item.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }
}
