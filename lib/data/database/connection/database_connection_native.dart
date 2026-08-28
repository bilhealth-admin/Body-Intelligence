import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../database_scope.dart';

const _legacyDatabaseFileName = 'body_intelligence.sqlite';
const _legacyScopeMarkerSuffix = '.scope';
const _ownerPreferenceKey = 'cloud.localDataOwner.v1';

QueryExecutor createDatabaseConnection({String? localOwnerId}) {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    if (!directory.existsSync()) directory.createSync(recursive: true);

    final target = File(
      p.join(directory.path, LocalDatabaseScope.databaseFileName(localOwnerId)),
    );

    await _adoptLegacyDatabaseIfSafe(
      directory: directory,
      target: target,
      localOwnerId: localOwnerId,
    );

    return NativeDatabase.createInBackground(target);
  });
}

Future<void> _adoptLegacyDatabaseIfSafe({
  required Directory directory,
  required File target,
  required String? localOwnerId,
}) async {
  if (target.existsSync()) return;

  final legacy = File(p.join(directory.path, _legacyDatabaseFileName));
  if (!legacy.existsSync()) return;

  final requestedScope = LocalDatabaseScope.keyForOwner(localOwnerId);
  final marker = File('${legacy.path}$_legacyScopeMarkerSuffix');
  if (marker.existsSync()) {
    final previouslyAdoptedScope = marker.readAsStringSync().trim();
    if (previouslyAdoptedScope != requestedScope) return;
    await _copyDatabaseFamily(legacy, target);
    return;
  }

  final probe = _probeLegacyOwner(legacy);
  if (!probe.readable) {
    // Fail closed: a database whose ownership cannot be read is never copied
    // into an authenticated account namespace.
    return;
  }
  if (!LocalDatabaseScope.canAdoptLegacyDatabase(
    activeOwnerId: localOwnerId,
    legacyOwnerId: probe.ownerId,
  )) {
    return;
  }

  await _copyDatabaseFamily(legacy, target);
  await marker.writeAsString(requestedScope, flush: true);
}

({bool readable, String? ownerId}) _probeLegacyOwner(File databaseFile) {
  Database? database;
  try {
    database = sqlite3.open(databaseFile.path, mode: OpenMode.readOnly);
    final preferencesTable = database.select(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='preferences' LIMIT 1",
    );
    if (preferencesTable.isEmpty) {
      return (readable: true, ownerId: null);
    }
    final rows = database.select(
      'SELECT value FROM preferences WHERE key = ? LIMIT 1',
      <Object?>[_ownerPreferenceKey],
    );
    if (rows.isEmpty) return (readable: true, ownerId: null);
    final value = rows.first['value'];
    if (value is! String || value.trim().isEmpty) {
      return (readable: true, ownerId: null);
    }
    return (readable: true, ownerId: value.trim());
  } on SqliteException {
    return (readable: false, ownerId: null);
  } finally {
    database?.close();
  }
}

Future<void> _copyDatabaseFamily(File source, File target) async {
  final sourcePaths = <String>[
    source.path,
    '${source.path}-wal',
    '${source.path}-shm',
    '${source.path}-journal',
  ];
  final targetPaths = <String>[
    target.path,
    '${target.path}-wal',
    '${target.path}-shm',
    '${target.path}-journal',
  ];

  final copiedTargets = <File>[];
  try {
    for (var index = 0; index < sourcePaths.length; index += 1) {
      final sourceFile = File(sourcePaths[index]);
      if (!sourceFile.existsSync()) continue;
      final targetFile = File(targetPaths[index]);
      await sourceFile.copy(targetFile.path);
      copiedTargets.add(targetFile);
    }

    // Keep the legacy database family as a fallback copy. The scoped target
    // becomes authoritative because it now exists. Retaining the source avoids
    // destructive migration risk and lets a failed rollout be recovered.
  } catch (_) {
    for (final targetFile in copiedTargets.reversed) {
      if (targetFile.existsSync()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
    }
    rethrow;
  }
}
