import 'dart:async';
import 'dart:io';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_auto_sync_coordinator.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../nutrition/gemini_vision_net_consumers_causal_test.dart'
    show owner, day, seedGemini;

/// Real Drift notifications and real production coordinator. Only transport is
/// replaced with a counter; this does not establish hosted/cloud consent proof.
class _Fixture {
  late AppDatabase db;
  late ProviderContainer container;
  late Supabase supabase;
  final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
  int calls = 0;
  Future<void> initialize({bool open = false}) async {
    SharedPreferences.setMockInitialValues({});
    supabase = await Supabase.initialize(
      url: 'https://auto-sync.invalid',
      publishableKey: 'synthetic-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (_) async => throw StateError('Scheduling fixture sends no HTTP'),
      ),
    );
    final folder = await Directory.systemTemp.createTemp(
      'bil-vision-lifecycle-sync-',
    );
    db = AppDatabase.forTesting(
      NativeDatabase(File('${folder.path}/owner.sqlite')),
      localOwnerId: owner,
    );
    await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
    await DailyLogRepository(db).startDay(day);
    await seedGemini(db, 16.9);
    await DailyLogRepository(db).closeDay(day);
    if (open) await DailyLogRepository(db).reopenDay(day);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        cloudAutoSyncRunnerProvider.overrideWith(
          (ref) => () async {
            calls++;
            return CloudManualSyncResult(
              disposition: CloudManualSyncDisposition.completed,
              ownerId: owner,
              completedAt: DateTime.utc(2026, 11, 18),
            );
          },
        ),
        cloudAutoSyncConnectivityChangesProvider.overrideWithValue(
          connectivity.stream,
        ),
      ],
    );
  }

  Future<void> settleSql(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
    }
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CloudAutoSyncCoordinator(child: SizedBox.expand()),
        ),
      ),
    );
    await settleSql(tester);
    expect(calls, 0);
  }

  Future<void> flush(WidgetTester tester) async {
    await settleSql(tester);
    await tester.pump(const Duration(seconds: 2));
    await settleSql(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    container.dispose();
    await settleSql(tester);
    await tester.runAsync(() async {
      await connectivity.close();
      await db.close();
      await supabase.dispose();
    });
  }
}

void main() {
  testWidgets(
    'Vision reopen alone schedules one real automatic sync without a meal write',
    (tester) async {
      final f = _Fixture();
      await tester.runAsync(f.initialize);
      try {
        await f.mount(tester);
        final before = await tester.runAsync(
          () => f.db.select(f.db.mealItems).get(),
        );
        await tester.runAsync(() => DailyLogRepository(f.db).reopenDay(day));
        await f.flush(tester);
        expect(f.calls, 1);
        final after = await tester.runAsync(
          () => f.db.select(f.db.mealItems).get(),
        );
        expect(
          after!.map((r) => r.toJson()).toList(),
          before!.map((r) => r.toJson()).toList(),
        );
        await tester.pump(const Duration(seconds: 30));
        expect(f.calls, 1);
      } finally {
        await f.close(tester);
      }
    },
  );
  testWidgets(
    'Vision close alone schedules one real automatic sync without a meal write',
    (tester) async {
      final f = _Fixture();
      await tester.runAsync(() => f.initialize(open: true));
      try {
        await f.mount(tester);
        await tester.runAsync(() => DailyLogRepository(f.db).closeDay(day));
        await f.flush(tester);
        expect(f.calls, 1);
        await tester.pump(const Duration(seconds: 30));
        expect(f.calls, 1);
      } finally {
        await f.close(tester);
      }
    },
  );
  testWidgets(
    'private daily fields and legacy non-Vision lifecycle never trigger the new watcher',
    (tester) async {
      final f = _Fixture();
      await tester.runAsync(f.initialize);
      try {
        await f.mount(tester);
        await tester.runAsync(
          () => DailyLogRepository(f.db).save(
            date: day,
            notes: 'Synthetic private note',
            sleepHours: 7,
            steps: 123,
            exerciseNotes: 'Synthetic activity',
          ),
        );
        // Drain the real SQLite notification before the next mutation enters
        // runAsync. Otherwise a watcher started in the fake widget zone can hold
        // its executor while the real-zone batch awaits that same executor.
        await f.settleSql(tester);
        final legacy = day.subtract(const Duration(days: 1));
        await tester.runAsync(() => DailyLogRepository(f.db).startDay(legacy));
        await f.settleSql(tester);
        await tester.runAsync(() => DailyLogRepository(f.db).closeDay(legacy));
        await f.settleSql(tester);
        await tester.runAsync(() => DailyLogRepository(f.db).reopenDay(legacy));
        await f.flush(tester);
        expect(f.calls, 0);
        await tester.pump(const Duration(seconds: 30));
        expect(f.calls, 0);
      } finally {
        await f.close(tester);
      }
    },
  );
}
