part of 'dashboard_preferences_release_matrix_test.dart';

_PreparedPreferencesFixture? _preparedPreferencesFixture;
final _openFixtureDatabases = <_TrackedFixtureDatabase>{};

class _TrackedFixtureDatabase {
  _TrackedFixtureDatabase(this.file)
    : database = AppDatabase.forTesting(NativeDatabase(file)) {
    _openFixtureDatabases.add(this);
  }
  final File file;
  final AppDatabase database;
  bool closed = false;
  Future<void> close() async {
    if (closed) return;
    await database.close();
    closed = true;
    _openFixtureDatabases.remove(this);
  }
}

void _deleteFixtureDirectory(Directory directory) {
  expect(directory.parent.absolute.path, Directory.systemTemp.absolute.path);
  final open = _openFixtureDatabases.where(
    (lease) => lease.file.parent.absolute.path == directory.absolute.path,
  );
  if (open.isNotEmpty) {
    throw StateError(
      'Fixture cleanup blocked; retained owned directory with '
      '${open.length} unclosed SQLite handle(s): ${directory.path}',
    );
  }
  directory.deleteSync(recursive: true);
}

class _PreparedPreferencesFixture {
  _PreparedPreferencesFixture.create()
    : directory = Directory.systemTemp.createTempSync('bil-preferences-seed-');
  final Directory directory;
  List<int>? _closedBytes;
  Future<void>? _initialization;
  _TrackedFixtureDatabase? _initializationLease;
  bool _initializationSettled = false;

  Future<void> initialize({
    Duration initializationBudget = const Duration(seconds: 55),
    Duration totalBudget = const Duration(seconds: 60),
    Future<void> Function()? afterNativeInitialization,
  }) async {
    final watch = Stopwatch()..start();
    final lease = _initializationLease = _TrackedFixtureDatabase(
      File('${directory.path}/seed.sqlite'),
    );
    Object? original;
    StackTrace? originalStack;
    Duration remaining() {
      final available = totalBudget - watch.elapsed;
      if (available <= Duration.zero) {
        throw TimeoutException('fixture_setup configured total budget expired');
      }
      return available;
    }

    debugPrint(
      'PREFERENCES_FIXTURE stage=fixture_setup phase=start '
      'configured_budget_ms=${totalBudget.inMilliseconds} '
      'native_call_cancellable=false not_ui_acceptance=true',
    );
    // test_api runs setUpAll as its own12-minute scaffold, outside widget30.
    // These explicit budgets/post-blocking checks bound our fixture acceptance.
    final initialization = _initialization = (() async {
      await lease.database.customSelect('SELECT 1').get();
      final version = await lease.database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), lease.database.schemaVersion);
      final rows = await lease.database
          .select(lease.database.preferences)
          .get();
      expect(rows, isEmpty);
      final journal = await lease.database
          .customSelect('PRAGMA journal_mode')
          .getSingle();
      expect(
        journal.data.values.single,
        isNot('wal'),
        reason: 'The closed seed must not depend on an uncopied WAL.',
      );
      if (afterNativeInitialization != null) await afterNativeInitialization();
    })().whenComplete(() => _initializationSettled = true);
    try {
      await initialization.timeout(initializationBudget);
      _checkFixtureBudget(watch, initializationBudget, 'fixture_setup init');
    } catch (error, stack) {
      debugPrint(
        'PREFERENCES_FIXTURE stage=fixture_setup phase=failed error=$error',
      );
      original = error;
      originalStack = stack;
    }
    if (!_initializationSettled) {
      // Future.timeout cannot cancel initialization. Never close a live query.
      try {
        await initialization.timeout(remaining());
      } catch (error, stack) {
        if (!_initializationSettled) {
          throw _FixtureFailure([
            (stage: 'fixture_setup', error: original!, stack: originalStack!),
            (
              stage:
                  'pending fixture_setup; retained owned path ${directory.path}',
              error: error,
              stack: stack,
            ),
          ]);
        }
        // A settled initialization error is safe to close; preserve the first
        // deadline as the primary failure rather than accepting its late result.
      }
    }
    final closeWatch = Stopwatch()..start();
    try {
      final available = remaining();
      final closeBudget = available < const Duration(seconds: 5)
          ? available
          : const Duration(seconds: 5);
      await lease.close().timeout(closeBudget);
      _checkFixtureBudget(closeWatch, closeBudget, 'fixture_setup close');
    } catch (error, stack) {
      if (original != null) {
        throw _FixtureFailure([
          (stage: 'fixture_setup', error: original, stack: originalStack!),
          (stage: 'fixture_setup close', error: error, stack: stack),
        ]);
      }
      rethrow;
    } finally {
      debugPrint(
        'PREFERENCES_FIXTURE stage=fixture_setup phase=end '
        'elapsed_ms=${watch.elapsedMilliseconds} closed=${lease.closed} '
        'not_ui_acceptance=true',
      );
    }
    if (original != null) Error.throwWithStackTrace(original, originalStack!);
    final bytes = lease.file.readAsBytesSync();
    _checkFixtureBudget(watch, totalBudget, 'fixture_setup total');
    _closedBytes = List<int>.unmodifiable(bytes);
  }

  void materialize(File destination) {
    final bytes = _closedBytes;
    if (bytes == null) throw StateError('fixture_setup did not complete');
    if (destination.existsSync()) {
      throw StateError('Refusing to overwrite a fixture database');
    }
    destination.writeAsBytesSync(bytes, flush: true);
  }

  void dispose() => _deleteFixtureDirectory(directory);
}

final _fixtureHosts = Expando<_FixtureHostTasks>();
_FixtureHostTasks _fixtureHostTasks(WidgetTester tester) =>
    _fixtureHosts[tester] ??= _FixtureHostTasks();

Future<T?> _fixtureRunAsync<T>(
  WidgetTester tester,
  Future<T> Function() operation,
) => _fixtureHostTasks(tester).run(tester, operation);

class _FixtureHostTasks {
  Future<Object?>? _pending;
  Future<T?> run<T>(WidgetTester tester, Future<T> Function() operation) {
    if (_pending != null) {
      throw StateError('Fixture host operation is already pending');
    }
    final raw = tester.runAsync(operation);
    _pending = raw;
    void clear() {
      if (identical(_pending, raw)) _pending = null;
    }

    // Do not schedule completion into a fake zone that teardown cannot pump.
    Zone.root.run(
      () => raw.then<void>(
        (_) => clear(),
        onError: (Object error, StackTrace stack) => clear(),
      ),
    );
    return raw;
  }

  Future<void> drain() async {
    final pending = _pending;
    if (pending == null) return;
    final watch = Stopwatch()..start();
    debugPrint(
      'PREFERENCES_FIXTURE stage=host_drain phase=start max_seconds=15',
    );
    try {
      await Zone.root.run(() => pending.timeout(const Duration(seconds: 15)));
      _checkFixtureBudget(watch, const Duration(seconds: 15), 'host_drain');
    } finally {
      debugPrint(
        'PREFERENCES_FIXTURE stage=host_drain phase=end '
        'elapsed_ms=${watch.elapsedMilliseconds} pending=${_pending != null}',
      );
    }
  }
}

// A native FFI call can block the event loop, preventing a Timer from firing.
// Never accept its late result merely because Future.timeout completed first.
void _checkFixtureBudget(Stopwatch watch, Duration budget, String stage) {
  if (watch.elapsed > budget) {
    throw TimeoutException(
      '$stage exceeded its configured budget after completion: '
      '${watch.elapsedMilliseconds}ms > ${budget.inMilliseconds}ms',
    );
  }
}
