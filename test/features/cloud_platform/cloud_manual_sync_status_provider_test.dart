import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ownerId = 'owner-a';
  late AppDatabase database;
  late PreferencesRepository preferences;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
  });

  tearDown(() => database.close());

  test(
    'hydrate distinguishes never, unavailable, and a genuine saved time',
    () async {
      final never = CloudManualSyncStatusController(
        preferences: preferences,
        runSync: _unusedSync,
        cloudAvailable: true,
        ownerId: ownerId,
      );
      await never.hydrate();
      expect(never.state.phase, CloudManualSyncPhase.never);
      expect(never.state.lastSuccessfulSyncAt, isNull);

      final genuine = DateTime.utc(2026, 8, 21, 9, 30);
      await preferences.set(
        cloudLastSuccessfulSyncPreferenceKeyFor(ownerId),
        genuine.toIso8601String(),
      );
      final idle = CloudManualSyncStatusController(
        preferences: preferences,
        runSync: _unusedSync,
        cloudAvailable: true,
        ownerId: ownerId,
      );
      await idle.hydrate();
      expect(idle.state.phase, CloudManualSyncPhase.idle);
      expect(idle.state.lastSuccessfulSyncAt, genuine);

      final unavailable = CloudManualSyncStatusController(
        preferences: preferences,
        runSync: _unusedSync,
        cloudAvailable: false,
        ownerId: ownerId,
      );
      await unavailable.hydrate();
      expect(unavailable.state.phase, CloudManualSyncPhase.unavailable);
      expect(unavailable.state.lastSuccessfulSyncAt, isNull);
    },
  );

  test('successful sync persists only the report completion instant', () async {
    final completedAt = DateTime.utc(2026, 8, 21, 10, 45, 12);
    final controller = CloudManualSyncStatusController(
      preferences: preferences,
      runSync: () async => CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.completed,
        completedAt: completedAt,
        ownerId: ownerId,
      ),
      cloudAvailable: true,
      ownerId: ownerId,
    );
    await controller.hydrate();

    final result = await controller.runOnce();

    expect(result.completed, isTrue);
    expect(controller.state.phase, CloudManualSyncPhase.idle);
    expect(controller.state.lastSuccessfulSyncAt, completedAt);
    expect(
      await preferences.get(cloudLastSuccessfulSyncPreferenceKeyFor(ownerId)),
      completedAt.toIso8601String(),
    );
  });

  test(
    'saved completion time is isolated to its authenticated owner',
    () async {
      final firstOwnerTime = DateTime.utc(2026, 8, 21, 10);
      await preferences.set(
        cloudLastSuccessfulSyncPreferenceKeyFor(ownerId),
        firstOwnerTime.toIso8601String(),
      );
      final secondOwner = CloudManualSyncStatusController(
        preferences: preferences,
        runSync: _unusedSync,
        cloudAvailable: true,
        ownerId: 'owner-b',
      );

      await secondOwner.hydrate();

      expect(secondOwner.state.phase, CloudManualSyncPhase.never);
      expect(secondOwner.state.lastSuccessfulSyncAt, isNull);
    },
  );

  test('a completion report for another owner is rejected', () async {
    final controller = CloudManualSyncStatusController(
      preferences: preferences,
      runSync: () async => CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.completed,
        completedAt: DateTime.utc(2026, 8, 21, 11),
        ownerId: 'owner-b',
      ),
      cloudAvailable: true,
      ownerId: ownerId,
    );

    await controller.runOnce();

    expect(controller.state.phase, CloudManualSyncPhase.unavailable);
    expect(controller.state.lastSuccessfulSyncAt, isNull);
    expect(
      await preferences.get(cloudLastSuccessfulSyncPreferenceKeyFor(ownerId)),
      isNull,
    );
  });

  test(
    'failed sync retains the prior true time and never replaces it',
    () async {
      final prior = DateTime.utc(2026, 8, 20, 8);
      await preferences.set(
        cloudLastSuccessfulSyncPreferenceKeyFor(ownerId),
        prior.toIso8601String(),
      );
      final controller = CloudManualSyncStatusController(
        preferences: preferences,
        runSync: () async => const CloudManualSyncResult(
          disposition: CloudManualSyncDisposition.offline,
        ),
        cloudAvailable: true,
        ownerId: ownerId,
      );
      await controller.hydrate();

      final result = await controller.runOnce();

      expect(result.disposition, CloudManualSyncDisposition.offline);
      expect(controller.state.phase, CloudManualSyncPhase.unavailable);
      expect(controller.state.lastSuccessfulSyncAt, prior);
      expect(
        await preferences.get(cloudLastSuccessfulSyncPreferenceKeyFor(ownerId)),
        prior.toIso8601String(),
      );
    },
  );

  test(
    'run waits for hydration so a real saved time cannot be raced away',
    () async {
      final prior = DateTime.utc(2026, 8, 20, 8);
      final delayed = _DelayedPreferencesRepository(database);
      final controller = CloudManualSyncStatusController(
        preferences: delayed,
        runSync: () async => const CloudManualSyncResult(
          disposition: CloudManualSyncDisposition.offline,
        ),
        cloudAvailable: true,
        ownerId: ownerId,
      );

      final run = controller.runOnce();
      expect(controller.state.phase, CloudManualSyncPhase.loading);
      delayed.complete(prior.toIso8601String());
      await run;

      expect(controller.state.phase, CloudManualSyncPhase.unavailable);
      expect(controller.state.lastSuccessfulSyncAt, prior);
    },
  );

  test(
    'successful report stays durable if its screen is disposed mid-sync',
    () async {
      final completedAt = DateTime.utc(2026, 8, 21, 12);
      final pending = Completer<CloudManualSyncResult>();
      final controller = CloudManualSyncStatusController(
        preferences: preferences,
        runSync: () => pending.future,
        cloudAvailable: true,
        ownerId: ownerId,
      );
      await controller.hydrate();

      final run = controller.runOnce();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.phase, CloudManualSyncPhase.syncing);
      controller.dispose();
      pending.complete(
        CloudManualSyncResult(
          disposition: CloudManualSyncDisposition.completed,
          completedAt: completedAt,
          ownerId: ownerId,
        ),
      );
      await expectLater(run, completes);

      expect(
        await preferences.get(cloudLastSuccessfulSyncPreferenceKeyFor(ownerId)),
        completedAt.toIso8601String(),
      );
    },
  );
}

Future<CloudManualSyncResult> _unusedSync() => throw StateError('not called');

final class _DelayedPreferencesRepository extends PreferencesRepository {
  _DelayedPreferencesRepository(super.database);

  final _value = Completer<String?>();

  void complete(String? value) => _value.complete(value);

  @override
  Future<String?> get(String key) => _value.future;
}
