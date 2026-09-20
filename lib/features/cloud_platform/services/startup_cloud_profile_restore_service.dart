import 'dart:async';

import '../domain/cloud_sync_models.dart';

abstract interface class StartupCloudProfileReader {
  Future<List<CloudRecordEnvelope>> readRestoreRecords(String ownerId);
}

typedef StartupOwnerReader = String? Function();
typedef StartupBoundOwnerReader = Future<String?> Function();
typedef StartupLocalProfileReader = Future<bool> Function();
typedef StartupLocalRecordsApplier =
    Future<bool> Function(List<CloudRecordEnvelope> records);

const startupCloudRestoreEntityKinds = <CloudEntityKind>{
  CloudEntityKind.profile,
  CloudEntityKind.weight,
  CloudEntityKind.hydration,
};

/// A bounded, selective progress recovery used before startup routing.
///
/// The remote side is read-only. This coordinator never starts general cloud
/// synchronization and re-checks both session and local ownership immediately
/// before the one allowed mutation: atomically restoring the decrypted profile,
/// weight and hydration batch into the matching device-local database.
final class StartupCloudProfileRestoreService {
  const StartupCloudProfileRestoreService({
    required this.currentOwnerId,
    required this.readBoundOwnerId,
    required this.hasLocalProfile,
    required this.reader,
    required this.applyLocalRecords,
    this.timeout = const Duration(seconds: 6),
  });

  final StartupOwnerReader currentOwnerId;
  final StartupBoundOwnerReader readBoundOwnerId;
  final StartupLocalProfileReader hasLocalProfile;
  final StartupCloudProfileReader reader;
  final StartupLocalRecordsApplier applyLocalRecords;
  final Duration timeout;

  Future<bool> restore(String ownerId) async {
    final owner = ownerId.trim();
    if (owner.isEmpty || timeout <= Duration.zero) return false;
    final elapsed = Stopwatch()..start();

    Future<T> beforeDeadline<T>(Future<T> Function() operation) {
      final remaining = timeout - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Startup cloud restore timed out.', timeout);
      }
      // Time out the individual awaited operation instead of the whole restore
      // Future. A late network result is then ignored and can never continue on
      // to the local mutation after the caller has already seen a timeout.
      return operation().timeout(remaining);
    }

    return _restore(owner, beforeDeadline);
  }

  Future<bool> _restore(
    String ownerId,
    Future<T> Function<T>(Future<T> Function() operation) beforeDeadline,
  ) async {
    if (currentOwnerId() != ownerId) return false;
    if (await beforeDeadline(readBoundOwnerId) != ownerId) return false;
    if (await beforeDeadline(hasLocalProfile)) return true;

    final records = await beforeDeadline(
      () => reader.readRestoreRecords(ownerId),
    );
    final profiles = records
        .where((record) => record.entityKind == CloudEntityKind.profile)
        .toList(growable: false);
    final stableKeys = records.map((record) => record.stableKey).toSet();
    if (profiles.length != 1 ||
        records.isEmpty ||
        stableKeys.length != records.length ||
        records.any(
          (record) =>
              record.ownerId != ownerId ||
              record.isTombstone ||
              !startupCloudRestoreEntityKinds.contains(record.entityKind),
        )) {
      return false;
    }

    // The account may change while the network read is in flight.
    if (currentOwnerId() != ownerId ||
        await beforeDeadline(readBoundOwnerId) != ownerId ||
        await beforeDeadline(hasLocalProfile)) {
      return false;
    }
    final ordered = <CloudRecordEnvelope>[
      profiles.single,
      ...records.where(
        (record) => record.entityKind != CloudEntityKind.profile,
      ),
    ];
    // Production supplies one database transaction for this whole list. Do not
    // put a timeout around that transaction: reporting a timeout while a local
    // commit can still finish would make retry behavior non-deterministic.
    return applyLocalRecords(List.unmodifiable(ordered));
  }
}
