import 'dart:async';

import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_consent_repository.dart';

final class RestoreConsentFixture implements CloudRestoreConsentBackend {
  final owners = StreamController<String?>.broadcast(sync: true);
  @override
  String? ownerId = 'owner-a';
  @override
  Stream<String?> get ownerChanges => owners.stream;
  bool baseGranted = true;
  bool unsupported = false;
  bool failWrite = false;
  bool failRead = false;
  String receiptTime = '2026-10-12T12:00:00Z';
  bool invalidReceipt = false;
  final grants = <String, Map<CloudRestoreScope, bool>>{};
  final writes = <(String, CloudRestoreScope, bool)>[];
  Completer<void>? readBarrier;
  Completer<void>? readStarted;
  Completer<void>? writeBarrier;

  void switchOwner(String? value) {
    ownerId = value;
    owners.add(value);
  }

  @override
  Future<bool> baseConsentGranted() async => baseGranted;
  @override
  Future<Object?> capabilities() async => unsupported
      ? {'protocol_version': 1}
      : {
          'protocol_version': 2,
          'scopes': ['nutrition', 'goals'],
          'consent_policy_version': '1',
        };
  @override
  Future<Object?> readConsent() async {
    final owner = ownerId;
    if (readStarted?.isCompleted == false) readStarted!.complete();
    await readBarrier?.future;
    if (failRead) throw StateError('fixture read failure');
    return {
      for (final scope in CloudRestoreScope.values)
        scope.name: {
          'granted': grants[owner]?[scope] ?? false,
          'policy_version': '1',
          'recorded_at': receiptTime,
        },
    };
  }

  @override
  Future<Object?> writeConsent(CloudRestoreScope scope, bool granted) async {
    final owner = ownerId!;
    writes.add((owner, scope, granted));
    await writeBarrier?.future;
    if (failWrite) throw StateError('fixture storage failure');
    if (invalidReceipt) return {'granted': granted};
    (grants[owner] ??= {})[scope] = granted;
    return {
      'scope': scope.name,
      'granted': granted,
      'policy_version': '1',
      'recorded_at': '2026-10-12T12:00:00Z',
    };
  }
}

final class RestoreChoiceMemory implements CloudRestoreConsentLocalStore {
  final choices = <String, Map<CloudRestoreScope, bool>>{};
  @override
  Future<Map<CloudRestoreScope, bool>> read(String ownerId) async =>
      Map.of(choices[ownerId] ?? {});
  @override
  Future<void> write(
    String ownerId,
    CloudRestoreScope scope,
    bool granted,
  ) async {
    (choices[ownerId] ??= {})[scope] = granted;
  }
}
