part of 'dashboard_preferences_release_matrix_test.dart';

void _registerFixtureLifecycleCases() {
  testWidgets('preferences fixture closes after native warmup failure', (
    tester,
  ) async {
    final directory = _fixtureDirectory();
    final file = File('${directory.path}/preferences.sqlite');
    file.writeAsStringSync('This is not a SQLite database.');
    Object? original;
    try {
      await _PreferencesHarness.open(
        tester,
        databaseFile: file,
        language: 'en',
        brightness: Brightness.light,
        scale: 1,
        subscription: FreePlan.createState(),
      );
    } catch (error) {
      original = error;
    }
    expect(original, isNotNull);
    expect(original.toString(), contains('not a database'));
    // Windows refuses this deletion while NativeDatabase still owns the file.
    // This is an actual filesystem/SQLite assertion, not a disposal spy.
    file.deleteSync();
    expect(file.existsSync(), isFalse);
    await _proveNextFixture(tester, file);
  });

  testWidgets('preferences fixture disposes all resources after unmount failure', (
    tester,
  ) async {
    final directory = _fixtureDirectory();
    final file = File('${directory.path}/preferences.sqlite');
    final harness = await _PreferencesHarness.open(
      tester,
      databaseFile: file,
      language: 'en',
      brightness: Brightness.light,
      scale: 1,
      subscription: FreePlan.createState(),
    );
    final failure = StateError('forced unmount pump failure');
    final disposed = <String>[];
    // Exercise the same cleanup executor used by close, with a failing first
    // pump stage. No Flutter guard is disabled to manufacture a clean outcome.
    Object? actual;
    try {
      await _disposeFixtureResources([
        (
          stage: 'unmount',
          dispose: () async {
            await tester.pumpWidget(const SizedBox.shrink());
            throw failure;
          },
        ),
        (
          stage: 'router',
          dispose: () async {
            harness.router.dispose();
            disposed.add('router');
          },
        ),
        (
          stage: 'container',
          dispose: () async {
            harness.container.dispose();
            disposed.add('container');
          },
        ),
        (
          stage: 'database',
          dispose: () async {
            await _finishHost(tester, harness.lease.close, 'forced cleanup');
            disposed.add('database');
          },
        ),
      ]);
    } catch (error) {
      actual = error;
    }
    // Those real resources have already been disposed by the tested executor;
    // retire its owner so registered teardown cannot dispose them a second time.
    harness._retired = true;
    harness._cleanup._complete = true;
    expect(actual, same(failure));
    expect(disposed, ['router', 'container', 'database']);
    file.deleteSync();
    expect(file.existsSync(), isFalse);
    await _proveNextFixture(tester, file);
  });

  testWidgets('preferences fixture retires late continuation before mount', (
    tester,
  ) async {
    final directory = _fixtureDirectory();
    final file = File('${directory.path}/preferences.sqlite');
    final gate = Completer<void>();
    final reachedGate = Completer<_PreferencesHarness>();
    final pending = _PreferencesHarness.open(
      tester,
      databaseFile: file,
      language: 'en',
      brightness: Brightness.light,
      scale: 1,
      subscription: FreePlan.createState(),
      afterWarmup: (harness) {
        reachedGate.complete(harness);
        return gate.future;
      },
    );
    // Native warmup completes on its host loop; do not start another guarded
    // widget operation while open is still awaiting that real query.
    final retired = await reachedGate.future;
    await retired.close(tester);
    final rejected = expectLater(
      pending,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('retired'),
        ),
      ),
    );
    gate.complete();
    await rejected;
    expect(find.byType(DashboardPreferencesPage), findsNothing);
    file.deleteSync();
    await _proveNextFixture(tester, file);
  });

  test(
    'preferences fixture preserves original and every cleanup failure',
    () async {
      final original = StateError('original warmup error');
      final routerFailure = StateError('router disposal error');
      final databaseFailure = StateError('database disposal error');
      var lastResourceAttempted = false;
      await expectLater(
        _preserveFailureDuringCleanup(
          original,
          StackTrace.current,
          () => _disposeFixtureResources([
            (stage: 'router', dispose: () async => throw routerFailure),
            (
              stage: 'database',
              dispose: () async {
                lastResourceAttempted = true;
                throw databaseFailure;
              },
            ),
          ]),
        ),
        throwsA(
          isA<_FixtureFailure>()
              .having(
                (error) => error.failures.first.error,
                'original',
                same(original),
              )
              .having(
                (error) => error.toString(),
                'all diagnostics',
                allOf(
                  contains('router disposal error'),
                  contains('database disposal error'),
                  contains('original warmup error'),
                ),
              ),
        ),
      );
      expect(lastResourceAttempted, isTrue);
    },
  );
}

Directory _fixtureDirectory() {
  final directory = Directory.systemTemp.createTempSync(
    'bil-preferences-lifecycle-',
  );
  addTearDown(() {
    expect(directory.parent.absolute.path, Directory.systemTemp.absolute.path);
    _deleteFixtureDirectory(directory);
  });
  return directory;
}

Future<void> _proveNextFixture(WidgetTester tester, File file) async {
  final next = await _PreferencesHarness.open(
    tester,
    databaseFile: file,
    language: 'en',
    brightness: Brightness.light,
    scale: 1,
    subscription: FreePlan.createState(),
  );
  expect(find.byType(DashboardPreferencesPage), findsOneWidget);
  await _finishHost(
    tester,
    () => next.preferences.set('fixture.next', 'isolated'),
    'next fixture write',
  );
  String? readback;
  await _finishHost(tester, () async {
    readback = await next.preferences.get('fixture.next');
  }, 'next fixture readback');
  expect(readback, 'isolated');
  _assertNoFrameworkErrors(tester, 'next case after retired fixture');
  await next.close(tester);
  file.deleteSync();
  expect(file.existsSync(), isFalse);
}
