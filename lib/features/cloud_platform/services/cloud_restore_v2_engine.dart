import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import 'cloud_nutrition_snapshot_codec.dart';
import 'cloud_platform_ports.dart';
import 'cloud_restore_v2_journal.dart';
import 'cloud_restore_v2_transport.dart';

part 'cloud_restore_v2_apply.dart';

final class CloudRestoreV2Report {
  const CloudRestoreV2Report({
    this.pushed = 0,
    this.pulled = 0,
    this.applied = 0,
    this.pending = 0,
    this.conflicts = 0,
    this.reason,
    this.scopes = const {},
    this.completedAt,
  });
  final int pushed, pulled, applied, pending, conflicts;

  /// Stable diagnostic code only. Never include payloads, keys or health data.
  final String? reason;
  final Set<String> scopes;
  final DateTime? completedAt;
  bool get completed => reason == null && pending == 0 && conflicts == 0;
}

/// One bounded synchronization pass. The server owns revision ordering; a
/// conflict is durable and requires an explicit choice, never a device clock.
final class CloudRestoreV2Engine {
  CloudRestoreV2Engine({
    required this.database,
    required this.ownerId,
    required this.deviceId,
    required this.keyId,
    required this.cipher,
    required this.transport,
    required this.ownerIsCurrent,
    this.pageSize = 100,
    this.maximumPages = 20,
    this.allowedScopes = const {'nutrition', 'goals'},
  }) : journal = CloudRestoreV2Journal(database, ownerId),
       codec = CloudNutritionSnapshotCodec(
         database,
         ownerId: ownerId,
         ownerIsCurrent: ownerIsCurrent,
       );

  final AppDatabase database;
  final String ownerId, deviceId, keyId;
  final CloudPayloadCipher cipher;
  final CloudRestoreV2Transport transport;

  /// Captures the session/consent epoch, not merely the current owner's ID.
  final bool Function() ownerIsCurrent;
  final int pageSize, maximumPages;
  final Set<String> allowedScopes;
  final CloudRestoreV2Journal journal;
  final CloudNutritionSnapshotCodec codec;
  bool _running = false;

  void _guard() {
    if (!ownerIsCurrent()) throw const _RestoreFailure('context_changed');
  }

  Future<void> _authorized(String scope) async {
    _guard();
    if (!allowedScopes.contains(scope)) {
      throw const _RestoreFailure('consent_missing');
    }
    final consent = await transport.consent();
    _guard();
    final receipt = consent[scope];
    if (receipt is! Map ||
        receipt['granted'] != true ||
        receipt['policy_version'] != '1') {
      throw const _RestoreFailure('consent_missing');
    }
  }

  Future<CloudRestoreV2Report> run(Set<String> requestedScopes) =>
      _RestoreDatabaseQueue.run(database, () => _run(requestedScopes));

  Future<CloudRestoreV2Report> _run(Set<String> requestedScopes) async {
    if (_running) return const CloudRestoreV2Report(reason: 'already_running');
    if (requestedScopes.isEmpty) return const CloudRestoreV2Report();
    _running = true;
    var pushed = 0, pulled = 0, applied = 0;
    String? reason;
    try {
      _guard();
      if (!cipher.isAvailable) throw const _RestoreFailure('key_unavailable');
      final capabilities = await transport.capabilities();
      _guard();
      final supported = capabilities['scopes'];
      if (capabilities['protocol_version'] != 2 ||
          supported is! List ||
          !requestedScopes.every(supported.contains)) {
        throw const _RestoreFailure('server_unsupported');
      }
      await journal.initialize();
      for (final scope in requestedScopes) {
        if (scope != 'nutrition' && scope != 'goals') {
          throw const _RestoreFailure('scope_unsupported');
        }
        await _authorized(scope);
        for (var page = 0; page < maximumPages; page++) {
          await _stage(scope);
          _guard();
          final rows = await journal.entries(scope);
          final outgoing = rows
              .where((r) => r.pending != null && r.conflict == null)
              .take(100)
              .toList();
          final cursor = await journal.cursor(scope);
          await _authorized(scope);
          final response = await transport.exchange(
            deviceId: deviceId,
            scope: scope,
            cursor: cursor,
            operations: outgoing.map((r) => r.pending!).toList(),
            limit: pageSize,
          );
          _guard();
          if (response['protocol_version'] != 2 ||
              response['scope'] != scope ||
              response['cursor'] is! int ||
              (response['cursor']! as int) < cursor ||
              response['has_more'] is! bool ||
              response['receipts'] is! List ||
              response['records'] is! List) {
            throw const _RestoreFailure('invalid_server_response');
          }
          // A revoked consent between download and application cannot silently
          // install data. Local revocation also invalidates the lease instantly.
          await _authorized(scope);
          final counts = await database.transaction(() async {
            _guard();
            var accepted = 0, installed = 0;
            for (final raw in response['receipts']! as List) {
              final receipt = Map<String, Object?>.from(raw as Map);
              final matches = outgoing.where(
                (r) => r.pending?['operation_id'] == receipt['operation_id'],
              );
              if (matches.length != 1) {
                throw const _RestoreFailure('invalid_receipt');
              }
              final row = (await journal.entry(matches.single.key))!;
              if (receipt['outcome'] == 'accepted') {
                final revision = receipt['server_revision'];
                if (revision is! int || revision <= row.revision) {
                  throw const _RestoreFailure('invalid_receipt_revision');
                }
                row.revision = revision;
                row.baseline = snapshotFingerprint(
                  CloudNutritionSnapshot.fromJson(row.pendingSnapshot!),
                );
                row.pending = null;
                row.pendingSnapshot = null;
                accepted++;
              } else if (receipt['outcome'] == 'conflict') {
                final current = receipt['current_record'];
                if (current is! Map) {
                  throw const _RestoreFailure('missing_conflict');
                }
                await _decodeRecord(Map<String, Object?>.from(current), scope);
                row.conflict = Map<String, Object?>.from(current);
              } else {
                throw const _RestoreFailure('unknown_receipt');
              }
              await journal.save(row);
            }
            if ((response['receipts']! as List).length != outgoing.length) {
              throw const _RestoreFailure('missing_receipt');
            }
            for (final raw in response['records']! as List) {
              if (await _installRecord(
                Map<String, Object?>.from(raw as Map),
                scope,
              )) {
                installed++;
              }
            }
            _guard();
            await journal.advance(scope, response['cursor']! as int);
            return (accepted, installed);
          });
          pushed += counts.$1;
          applied += counts.$2;
          pulled += (response['records']! as List).length;
          final remaining = await journal.entries(scope);
          final hasQueued = remaining.any(
            (r) => r.pending != null && r.conflict == null,
          );
          if (response['has_more'] == false && !hasQueued) break;
          if (page == maximumPages - 1) reason = 'page_limit';
        }
        // A local write can finish while the last network request is pending.
        // Capture it durably; completion must not describe that write as synced.
        await _stage(scope);
      }
    } on _RestoreFailure catch (error) {
      reason = error.code;
    } on FormatException {
      reason = 'payload_invalid_or_key_missing';
    } on Object {
      reason = 'transport_or_storage_unavailable';
    } finally {
      _running = false;
    }
    var pending = 0, conflicts = 0;
    try {
      for (final scope in requestedScopes) {
        for (final row in await journal.entries(scope)) {
          if (row.pending != null) pending++;
          if (row.conflict != null) conflicts++;
        }
      }
    } on Object {
      reason ??= 'journal_unavailable';
    }
    return CloudRestoreV2Report(
      pushed: pushed,
      pulled: pulled,
      applied: applied,
      pending: pending,
      conflicts: conflicts,
      reason: reason,
      scopes: requestedScopes,
      completedAt: reason == null && pending == 0 && conflicts == 0
          ? DateTime.now().toUtc()
          : null,
    );
  }

  Future<void> _stage(String scope) async {
    _guard();
    final captured = await codec.capture(scopes: {scope});
    final snapshots = {for (final value in captured) value.key: value};
    final stored = await journal.entries(scope);
    for (final row in stored) {
      // Physical deletion of a recipe or resetting all goal overrides still
      // needs a tombstone. Only identities previously seen locally qualify.
      if (!snapshots.containsKey(row.key) && row.baseline != null) {
        snapshots[row.key] = row.type == 'goals'
            ? codec.emptyGoalsSnapshot()
            : CloudNutritionSnapshot(
                scope: row.scope,
                type: row.type,
                id: row.id,
                deleted: true,
                data: {
                  'schema': CloudNutritionSnapshotCodec.schema,
                  'ownerId': ownerId,
                },
              );
      }
    }
    for (final snapshot in snapshots.values) {
      _guard();
      final row =
          await journal.entry(snapshot.key) ??
          RestoreJournalEntry(
            scope: snapshot.scope,
            type: snapshot.type,
            id: snapshot.id,
          );
      if (row.pending != null ||
          row.conflict != null ||
          row.baseline == snapshotFingerprint(snapshot)) {
        continue;
      }
      final operationId = const Uuid().v4();
      final encrypted = await cipher.encrypt({
        'owner_id': ownerId,
        'scope': scope,
        'record_type': snapshot.type,
        'record_id': snapshot.id,
        'deleted': snapshot.deleted,
        'payload_version': 2,
        'key_id': keyId,
        'snapshot': snapshot.toJson(),
      });
      _guard();
      // Ciphertext is frozen with the operation ID. A retry never changes its
      // nonce or request fingerprint, including after process termination.
      row.pending = {
        'operation_id': operationId,
        'record_type': snapshot.type,
        'record_id': snapshot.id,
        'expected_revision': row.revision,
        'mutation': snapshot.deleted ? 'delete' : 'upsert',
        'payload_version': 2,
        'payload': {...encrypted, 'key_id': keyId},
      };
      row.pendingSnapshot = snapshot.toJson();
      await journal.save(row);
    }
  }
}

String snapshotFingerprint(CloudNutritionSnapshot value) {
  final identity = value.deleted
      ? {
          'scope': value.scope,
          'type': value.type,
          'id': value.id,
          'deleted': true,
        }
      : value.toJson();
  return sha256
      .convert(utf8.encode(jsonEncode(_canonical(identity))))
      .toString();
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

final class _RestoreFailure implements Exception {
  const _RestoreFailure(this.code);
  final String code;
}

/// Manual sync, automatic sync and a conflict editor can share one database.
/// Their journals must never race even when they created different engines.
final class _RestoreDatabaseQueue {
  static final _tails = Expando<Future<void>>();
  static Future<T> run<T>(AppDatabase database, Future<T> Function() action) {
    final previous = _tails[database] ?? Future<void>.value();
    final result = previous.then((_) => action());
    _tails[database] = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}
