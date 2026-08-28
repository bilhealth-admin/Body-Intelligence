import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';

/// Result of binding the single local SQLite data set to an authenticated BIL
/// account.
///
/// Each authenticated BIL account now receives its own device-local database
/// namespace. This boundary remains as a fail-closed integrity check inside one
/// namespace so records can never be silently rebound to another account.
enum LocalDataAccountBindingDisposition {
  adoptedGuestData,
  matchedExistingOwner,
  reboundEmptyStore,
  ownerConflict,
}

final class LocalDataAccountBinding {
  const LocalDataAccountBinding({
    required this.disposition,
    required this.hasSubstantiveLocalData,
  });

  final LocalDataAccountBindingDisposition disposition;
  final bool hasSubstantiveLocalData;

  bool get requiresAccountResolution =>
      disposition == LocalDataAccountBindingDisposition.ownerConflict;
}

/// Fail-closed ownership boundary for the device-local health database.
///
/// - Guest data may be adopted by the first authenticated account.
/// - The same account may reopen the store normally.
/// - An empty store may be rebound to another account safely.
/// - A different account may not enter a scoped store that already contains
///   substantive data owned by another account (legacy/corruption fail-safe).
///
/// This service does not upload, delete, or merge health data.
final class LocalDataAccountBoundary {
  LocalDataAccountBoundary(this._database);

  static const ownerPreferenceKey = 'cloud.localDataOwner.v1';
  static const boundAtPreferenceKey = 'cloud.localDataOwnerBoundAt.v1';

  final AppDatabase _database;

  Future<LocalDataAccountBinding> bindAuthenticatedOwner(String ownerId) async {
    final normalizedOwner = ownerId.trim();
    if (normalizedOwner.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty');
    }

    return _database.transaction(() async {
      final existingOwner = await _readPreference(ownerPreferenceKey);
      final hasLocalData = await _hasSubstantiveLocalData();

      if (existingOwner == null || existingOwner.trim().isEmpty) {
        await _writeOwner(normalizedOwner);
        return LocalDataAccountBinding(
          disposition: LocalDataAccountBindingDisposition.adoptedGuestData,
          hasSubstantiveLocalData: hasLocalData,
        );
      }

      if (existingOwner == normalizedOwner) {
        return LocalDataAccountBinding(
          disposition: LocalDataAccountBindingDisposition.matchedExistingOwner,
          hasSubstantiveLocalData: hasLocalData,
        );
      }

      if (!hasLocalData) {
        await _writeOwner(normalizedOwner);
        return const LocalDataAccountBinding(
          disposition: LocalDataAccountBindingDisposition.reboundEmptyStore,
          hasSubstantiveLocalData: false,
        );
      }

      return const LocalDataAccountBinding(
        disposition: LocalDataAccountBindingDisposition.ownerConflict,
        hasSubstantiveLocalData: true,
      );
    });
  }

  Future<String?> readBoundOwnerId() => _readPreference(ownerPreferenceKey);

  Future<String?> _readPreference(String key) async {
    final row = await (_database.select(
      _database.preferences,
    )..where((item) => item.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeOwner(String ownerId) async {
    final now = DateTime.now().toUtc();
    for (final entry in <String, String>{
      ownerPreferenceKey: ownerId,
      boundAtPreferenceKey: now.toIso8601String(),
    }.entries) {
      await _database
          .into(_database.preferences)
          .insertOnConflictUpdate(
            PreferencesCompanion.insert(
              key: entry.key,
              value: entry.value,
              updatedAt: Value(now),
            ),
          );
    }
  }

  Future<bool> _hasSubstantiveLocalData() async {
    // Deliberately excludes seeded foods and generic preferences. Those are not
    // sufficient reason to bind a health data set to one account.
    final row = await _database.customSelect('''
      SELECT CASE WHEN
        EXISTS(SELECT 1 FROM user_profile LIMIT 1) OR
        EXISTS(SELECT 1 FROM weight_entries LIMIT 1) OR
        EXISTS(SELECT 1 FROM daily_logs LIMIT 1) OR
        EXISTS(SELECT 1 FROM meals LIMIT 1) OR
        EXISTS(SELECT 1 FROM meal_items LIMIT 1) OR
        EXISTS(SELECT 1 FROM goals LIMIT 1) OR
        EXISTS(SELECT 1 FROM water_entries LIMIT 1) OR
        EXISTS(SELECT 1 FROM favorites LIMIT 1) OR
        EXISTS(SELECT 1 FROM recent_foods LIMIT 1) OR
        EXISTS(SELECT 1 FROM life_context_entries LIMIT 1) OR
        EXISTS(SELECT 1 FROM decision_memories LIMIT 1) OR
        EXISTS(SELECT 1 FROM decision_outcome_transitions LIMIT 1) OR
        EXISTS(SELECT 1 FROM plan_settings LIMIT 1) OR
        EXISTS(SELECT 1 FROM personal_experiments LIMIT 1) OR
        EXISTS(SELECT 1 FROM challenges LIMIT 1) OR
        EXISTS(SELECT 1 FROM body_measurement_entries LIMIT 1)
      THEN 1 ELSE 0 END AS has_data
    ''').getSingle();
    return row.read<int>('has_data') == 1;
  }
}
