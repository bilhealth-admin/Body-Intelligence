import 'dart:async';
import 'dart:io';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_auto_sync_coordinator.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _selectedDatabase = NotifierProvider<_DatabaseSelection, AppDatabase>(
  () => throw StateError('fixture only'),
);

class _DatabaseSelection extends Notifier<AppDatabase> {
  _DatabaseSelection(this.initial);
  final AppDatabase initial;
  @override
  AppDatabase build() => initial;
  void select(AppDatabase database) => state = database;
}

CloudManualSyncResult _completed(String owner) => CloudManualSyncResult(
  disposition: CloudManualSyncDisposition.completed,
  ownerId: owner,
  completedAt: DateTime.utc(2026, 10, 13, 12),
);
CloudManualSyncResult _partial(
  String owner,
  String reason, {
  int pending = 0,
  int conflicts = 0,
}) => CloudManualSyncResult(
  disposition: CloudManualSyncDisposition.partial,
  ownerId: owner,
  reason: reason,
  pending: pending,
  conflicts: conflicts,
);

class _Fixture {
  late Directory folder;
  late AppDatabase a, b;
  late ProviderContainer container;
  late Supabase supabase;
  final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
  final calls = <String>[];
  Completer<CloudManualSyncResult>? held;
  final answers = <CloudManualSyncResult>[];
  int activeRuns = 0;
  int maximumRuns = 0;

  Future<void> initialize() async {
    stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC initialize");
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
      httpClient: MockClient((request) async {
        throw StateError('Scheduling fixture must not send a network request');
      }),
    );
    stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC sdk-ready");
    folder = await Directory.systemTemp.createTemp('bil-auto-sync-audit-');
    a = AppDatabase.forTesting(
      NativeDatabase(File('${folder.path}/a.sqlite')),
      localOwnerId: 'synthetic-owner-a',
    );
    b = AppDatabase.forTesting(
      NativeDatabase(File('${folder.path}/b.sqlite')),
      localOwnerId: 'synthetic-owner-b',
    );
    await LocalDataAccountBoundary(a).bindAuthenticatedOwner(a.localOwnerId!);
    await LocalDataAccountBoundary(b).bindAuthenticatedOwner(b.localOwnerId!);
    stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC native-owner-bindings-ready");
    container = ProviderContainer(
      overrides: [
        _selectedDatabase.overrideWith(() => _DatabaseSelection(a)),
        databaseProvider.overrideWith((ref) => ref.watch(_selectedDatabase)),
        cloudAutoSyncRunnerProvider.overrideWith((ref) => run),
        cloudAutoSyncConnectivityChangesProvider.overrideWithValue(
          connectivity.stream,
        ),
      ],
    );
  }

  Future<CloudManualSyncResult> run() async {
    final owner = container.read(databaseProvider).localOwnerId!;
    calls.add(owner);
    activeRuns++;
    if (activeRuns > maximumRuns) maximumRuns = activeRuns;
    try {
      final wait = held;
      if (wait != null) return await wait.future;
      if (answers.isNotEmpty) return answers.removeAt(0);
      return _completed(owner);
    } finally {
      activeRuns--;
    }
  }

  Future<void> mount(WidgetTester tester) async {
    stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC mount");
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CloudAutoSyncCoordinator(child: SizedBox.expand()),
        ),
      ),
    );
    await settleSql(tester);
  }

  Future<void> settleSql(WidgetTester tester) async {
    // Drift watch invalidations belong to the widget's fake clock. Awaiting a
    // second native SELECT inside runAsync can wait for that clock forever.
    // Pump actual watcher deliveries before and after yielding to file I/O.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
    }
  }

  Future<void> water(WidgetTester tester, AppDatabase database) async {
    stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC before-real-write");
    await tester.runAsync(
      () => WaterRepository(
        database,
      ).add(occurredAt: DateTime.utc(2026, 10, 13, 11), amountMl: 250),
    );
    stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC real-write-finished");
    await settleSql(tester);
    stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC watchers-delivered");
  }

  Future<void> switchTo(WidgetTester tester, AppDatabase database) async {
    container.read(_selectedDatabase.notifier).select(database);
    await tester.pump();
    await settleSql(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC cleanup-start");
    await tester.pump(const Duration(milliseconds: 20));
    container.dispose();
    await settleSql(tester);
    await tester.runAsync(() async {
      stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC connectivity-close");
      await connectivity.close();
      stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC sqlite-a-close");
      await a.close();
      stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC sqlite-b-close");
      await b.close();
      stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC sdk-close");
      await supabase.dispose();
      stdout.writeln("SQLITE_FIXTURE_DIAGNOSTIC cleanup-complete");
      // Retain databases under their ignored temp location on failure if desired.
      // No workspace recursive deletion belongs in this test.
    });
  }
}

void main() {
  for (final reason in [
    'cloud_sync_decrypt_failed',
    'cloud_sync_cursor_write_failed',
    'cloud_sync_dead_letters_pending',
    'server_or_consent_unavailable',
    'server_unsupported',
    'conflict_review_required',
    'key_version_unavailable',
  ]) {
    testWidgets(
      'automatic partial $reason does not poll an unchanged SQLite database',
      (tester) async {
        final f = _Fixture();
        await tester.runAsync(f.initialize);
        try {
          f.answers.add(
            _partial(
              f.a.localOwnerId!,
              reason,
              conflicts: reason == 'conflict_review_required' ? 1 : 0,
            ),
          );
          await f.mount(tester);
          await f.water(tester, f.a);
          await tester.pump(const Duration(seconds: 2));
          expect(f.calls, [f.a.localOwnerId]);
          await tester.pump(const Duration(seconds: 2));
          await tester.pump(const Duration(seconds: 30));
          expect(
            f.calls,
            [f.a.localOwnerId],
            reason:
                'An unavailable capability, missing key or manual conflict cannot be repaired by repeating the same request.',
          );
          expect(tester.takeException(), isNull);
        } finally {
          await f.close(tester);
        }
      },
    );
  }

  testWidgets(
    'legitimate pending local changes schedule one bounded follow-up',
    (tester) async {
      final f = _Fixture();
      await tester.runAsync(f.initialize);
      try {
        f.answers.add(
          _partial(f.a.localOwnerId!, 'pending_local_changes', pending: 1),
        );
        await f.mount(tester);
        await f.water(tester, f.a);
        await tester.pump(const Duration(seconds: 2));
        expect(f.calls.length, 1);
        await tester.pump(const Duration(seconds: 2));
        expect(f.calls, [f.a.localOwnerId, f.a.localOwnerId]);
        await tester.pump(const Duration(seconds: 30));
        expect(f.calls.length, 2);
        expect(f.maximumRuns, 1);
      } finally {
        await f.close(tester);
      }
    },
  );

  testWidgets(
    'SQLite hydration mutation during held completed run is not lost with its debounce',
    (tester) async {
      final f = _Fixture();
      await tester.runAsync(f.initialize);
      try {
        f.held = Completer<CloudManualSyncResult>();
        await f.mount(tester);
        await f.water(tester, f.a);
        await tester.pump(const Duration(seconds: 2));
        expect(f.calls.length, 1);
        // A caller deadline does not release still-running SDK work. A new
        // actual SQLite write after that deadline must wait, not overlap.
        await tester.pump(const Duration(seconds: 13));
        await f.water(tester, f.a);
        await tester.pump(const Duration(seconds: 2));
        expect(f.calls.length, 1);
        final wait = f.held!;
        f.held = null;
        wait.complete(_completed(f.a.localOwnerId!));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(f.calls, [f.a.localOwnerId, f.a.localOwnerId]);
        expect(
          await tester.runAsync(
            () => WaterRepository(f.a).totalForDay(DateTime.utc(2026, 10, 13)),
          ),
          500,
        );
        expect(f.maximumRuns, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await f.close(tester);
      }
    },
  );

  testWidgets(
    'database A B rebinds actual SQLite watchers and cancels the retired watcher',
    (tester) async {
      final f = _Fixture();
      await tester.runAsync(f.initialize);
      try {
        await f.mount(tester);
        await f.switchTo(tester, f.b);
        await f.water(tester, f.b);
        await tester.pump(const Duration(seconds: 2));
        expect(f.calls, [f.b.localOwnerId]);
        await f.water(tester, f.a);
        await tester.pump(const Duration(seconds: 2));
        expect(f.calls, [f.b.localOwnerId]);
        expect(
          await tester.runAsync(
            () => WaterRepository(f.b).totalForDay(DateTime.utc(2026, 10, 13)),
          ),
          250,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await f.close(tester);
      }
    },
  );

  testWidgets(
    'database A B A retires old debounce while preserving fresh A writes',
    (tester) async {
      final f = _Fixture();
      await tester.runAsync(f.initialize);
      try {
        await f.mount(tester);
        await f.water(tester, f.a);
        await tester.pump(const Duration(seconds: 1));
        await f.switchTo(tester, f.b);
        await f.switchTo(tester, f.a);
        await tester.pump(const Duration(seconds: 2));
        expect(
          f.calls,
          isEmpty,
          reason:
              'Returning to the same UUID does not revive a prior account visit.',
        );
        await f.water(tester, f.a);
        await tester.pump(const Duration(seconds: 2));
        expect(f.calls, [f.a.localOwnerId]);
      } finally {
        await f.close(tester);
      }
    },
  );

  testWidgets(
    'late A partial completion cannot schedule work for unmodified B',
    (tester) async {
      final f = _Fixture();
      await tester.runAsync(f.initialize);
      try {
        f.held = Completer<CloudManualSyncResult>();
        await f.mount(tester);
        await f.water(tester, f.a);
        await tester.pump(const Duration(seconds: 2));
        await f.switchTo(tester, f.b);
        final wait = f.held!;
        f.held = null;
        wait.complete(
          _partial(f.a.localOwnerId!, 'pending_local_changes', pending: 1),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(f.calls, [f.a.localOwnerId]);
      } finally {
        await f.close(tester);
      }
    },
  );

  testWidgets('B mutation queues behind held retired A without overlap', (
    tester,
  ) async {
    final f = _Fixture();
    await tester.runAsync(f.initialize);
    try {
      f.held = Completer<CloudManualSyncResult>();
      await f.mount(tester);
      await f.water(tester, f.a);
      await tester.pump(const Duration(seconds: 2));
      await f.switchTo(tester, f.b);
      await f.water(tester, f.b);
      await tester.pump(const Duration(seconds: 2));
      expect(f.calls, [f.a.localOwnerId]);
      final wait = f.held!;
      f.held = null;
      wait.complete(_completed(f.a.localOwnerId!));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(f.calls, [f.a.localOwnerId, f.b.localOwnerId]);
      expect(f.maximumRuns, 1);
    } finally {
      await f.close(tester);
    }
  });

  testWidgets('dispose cancels debounce and all SQLite watchers', (
    tester,
  ) async {
    final f = _Fixture();
    await tester.runAsync(f.initialize);
    try {
      await f.mount(tester);
      await f.water(tester, f.a);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(f.calls, isEmpty);
      await f.water(tester, f.a);
      await tester.pump(const Duration(seconds: 2));
      expect(f.calls, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await f.close(tester);
    }
  });
}
