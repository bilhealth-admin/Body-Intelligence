// SDK lifecycle controls only, not Production/device sync evidence.
// Actual controller and Riverpod autoDispose; only held preference I/O and
// an unavailable sync runner are deterministic fixtures. No authority grant.
import 'dart:async';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final observeDuringRun in [false, true]) {
    test(
      'actual manual controller held hydration lifetime: listener=$observeDuringRun',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final preferences = _HeldPreferences(database);
        var runs = 0;
        var disposed = 0;
        late CloudManualSyncStatusController controller;
        final provider =
            StateNotifierProvider.autoDispose<
              CloudManualSyncStatusController,
              CloudManualSyncStatus
            >((ref) {
              controller = CloudManualSyncStatusController(
                preferences: preferences,
                cloudAvailable: true,
                ownerId: 'synthetic-owner',
                runSync: () async {
                  runs++;
                  return const CloudManualSyncResult(
                    disposition: CloudManualSyncDisposition.unavailable,
                    ownerId: 'synthetic-owner',
                  );
                },
              );
              ref.onDispose(() => disposed++);
              // Same eager hydration boundary as production provider factory.
              unawaited(controller.hydrate());
              return controller;
            });
        final container = ProviderContainer();
        ProviderSubscription<CloudManualSyncStatus>? observer;
        try {
          if (observeDuringRun) {
            observer = container.listen(provider, (_, _) {});
          }
          final run = container.read(provider.notifier).runOnce();
          expect(preferences.hydrationReads, 1);
          expect(preferences.hydrated.isCompleted, isFalse);
          // Official scheduler synchronization, no arbitrary delays/invalidate.
          await container.pump();
          expect(controller.mounted, observeDuringRun);
          expect(disposed, observeDuringRun ? 0 : 1);
          preferences.hydrated.complete(null);
          await run;
          expect(
            runs,
            observeDuringRun ? 1 : 0,
            reason:
                'Without a strong listener, await hydrate resumes after controller disposal and returns before the runner.',
          );
          if (observeDuringRun) {
            expect(controller.mounted, isTrue);
            observer!.close();
            observer = null;
            await container.pump();
            expect(controller.mounted, isFalse);
            expect(disposed, 1);
          }
        } finally {
          if (!preferences.hydrated.isCompleted) {
            preferences.hydrated.complete(null);
          }
          observer?.close();
          container.dispose();
          await database.close();
        }
      },
    );
  }
}

class _HeldPreferences extends PreferencesRepository {
  _HeldPreferences(super.database);
  final hydrated = Completer<String?>();
  var hydrationReads = 0;
  final values = <String, String>{};
  @override
  Future<String?> get(String key) {
    if (key == cloudLastSuccessfulSyncPreferenceKeyFor('synthetic-owner')) {
      hydrationReads++;
      return hydrated.future;
    }
    return Future.value(values[key]);
  }

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}
