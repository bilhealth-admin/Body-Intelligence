import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import 'cloud_restore_consent_repository.dart';
import 'local_data_account_boundary.dart';

/// Mirrored intent is not a grant. In particular, a failed revoke is preserved
/// locally and prevents an old server receipt resuming uploads after restart.
final class AppDatabaseCloudRestoreConsentLocalStore
    implements CloudRestoreConsentLocalStore {
  const AppDatabaseCloudRestoreConsentLocalStore(this.database);
  final AppDatabase database;

  String _key(String owner) => 'cloud.restore.choice.v2.$owner';

  Future<void> _checkOwner(String owner) async {
    if (await LocalDataAccountBoundary(database).readBoundOwnerId() != owner) {
      throw StateError('Cloud restore preferences belong to another account.');
    }
  }

  @override
  Future<Map<CloudRestoreScope, bool>> read(String ownerId) async {
    await _checkOwner(ownerId);
    final row = await (database.select(
      database.preferences,
    )..where((row) => row.key.equals(_key(ownerId)))).getSingleOrNull();
    if (row == null) return {};
    final decoded = jsonDecode(row.value);
    if (decoded is! Map || decoded['owner_id'] != ownerId) {
      throw const FormatException('Invalid cloud restore choice owner');
    }
    final choices = <CloudRestoreScope, bool>{};
    for (final scope in CloudRestoreScope.values) {
      final value = decoded[scope.name];
      if (value != null && value is! bool) {
        throw const FormatException('Invalid cloud restore choice');
      }
      if (value is bool) choices[scope] = value;
    }
    return choices;
  }

  @override
  Future<void> write(String ownerId, CloudRestoreScope scope, bool granted) =>
      database.transaction(() async {
        final choices = await read(ownerId);
        choices[scope] = granted;
        await database
            .into(database.preferences)
            .insertOnConflictUpdate(
              PreferencesCompanion.insert(
                key: _key(ownerId),
                value: jsonEncode({
                  'owner_id': ownerId,
                  for (final entry in choices.entries)
                    entry.key.name: entry.value,
                }),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
      });
}
