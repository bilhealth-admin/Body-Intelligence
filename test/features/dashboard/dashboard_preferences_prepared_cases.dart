part of 'dashboard_preferences_release_matrix_test.dart';

void _registerPreparedFixtureCases() {
  test(
    'pending native seed initialization is retained rather than closed or copied',
    () async {
      final fixture = _PreparedPreferencesFixture.create();
      final gate = Completer<void>();
      final reached = Completer<void>();
      _preparedPreferencesFixture!.materialize(
        File('${fixture.directory.path}/seed.sqlite'),
      );
      try {
        await expectLater(
          fixture.initialize(
            initializationBudget: const Duration(milliseconds: 150),
            totalBudget: const Duration(milliseconds: 300),
            afterNativeInitialization: () {
              reached.complete();
              return gate.future;
            },
          ),
          throwsA(isA<_FixtureFailure>()),
        );
        expect(reached.isCompleted, isTrue);
        expect(fixture._initializationSettled, isFalse);
        expect(fixture._initializationLease!.closed, isFalse);
        expect(
          () => fixture.materialize(
            File('${fixture.directory.path}/unsafe-copy.sqlite'),
          ),
          throwsStateError,
        );
        expect(() => fixture.dispose(), throwsStateError);
        expect(fixture.directory.existsSync(), isTrue);
      } finally {
        gate.complete();
        await fixture._initialization!.timeout(const Duration(seconds: 5));
        await fixture._initializationLease!.close().timeout(
          const Duration(seconds: 5),
        );
        fixture.dispose();
      }
      expect(fixture.directory.existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
  test(
    'post-blocking fixture budget rejects a late completed result',
    () async {
      final watch = Stopwatch()..start();
      final late = await Future<int>(() {
        sleep(const Duration(milliseconds: 25));
        return 42;
      }).timeout(const Duration(milliseconds: 5));
      expect(
        late,
        42,
        reason:
            'A blocked event loop can deliver completion before its expired Timer.',
      );
      expect(
        () => _checkFixtureBudget(
          watch,
          const Duration(milliseconds: 5),
          'controlled fixture setup',
        ),
        throwsA(isA<TimeoutException>()),
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'prepared real SQLite clones are independent and retain production schema',
    () async {
      final directory = _fixtureDirectory();
      final files = [
        for (final name in ['left', 'right', 'next'])
          File('${directory.path}/$name.sqlite'),
      ];
      final seed = _preparedPreferencesFixture!;
      final original = List<int>.of(seed._closedBytes!);
      for (final file in files) {
        seed.materialize(file);
      }
      for (var index = 0; index < files.length; index++) {
        final lease = _TrackedFixtureDatabase(files[index]);
        try {
          final version = await lease.database
              .customSelect('PRAGMA user_version')
              .getSingle();
          expect(
            version.read<int>('user_version'),
            lease.database.schemaVersion,
          );
          final preferences = PreferencesRepository(lease.database);
          if (index == 0) {
            await preferences.set('isolation', 'left only');
            expect(await preferences.get('isolation'), 'left only');
          } else {
            expect(await preferences.get('isolation'), isNull);
          }
        } finally {
          await lease.close();
        }
      }
      expect(seed._closedBytes, original);
      expect(
        File('${seed.directory.path}/seed.sqlite').readAsBytesSync(),
        original,
      );
      for (final file in files) {
        file.deleteSync();
        expect(file.existsSync(), isFalse);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'root deadline retires a pending real host task before cleanup reentry',
    (tester) async {
      final directory = _fixtureDirectory();
      final file = File('${directory.path}/preferences.sqlite');
      final harness = await _openDeadlineFixture(tester, file);
      final cleanup = Completer<void>();
      var deadlineObservedPending = false;
      final testZone = Zone.current;
      Zone.root.run(
        () => Timer(
          const Duration(milliseconds: 10),
          () => testZone.run(() {
            deadlineObservedPending =
                _fixtureHostTasks(tester)._pending != null;
            harness
                .close(tester)
                .then(cleanup.complete, onError: cleanup.completeError);
          }),
        ),
      );
      await _fixtureRunAsync(
        tester,
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      expect(() => harness._checkOpen(), throwsStateError);
      await cleanup.future;
      expect(deadlineObservedPending, isTrue);
      expect(harness.lease.closed, isTrue);
      file.deleteSync();
      expect(file.existsSync(), isFalse);
      await _proveNextFixture(tester, file);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'actual widget deadline drains SQLite and lets the next case execute',
    () async {
      final configFile = File('.dart_tool/package_config.json');
      final config = jsonDecode(configFile.readAsStringSync()) as Map;
      final packages = config['packages'] as List;
      final flutter = packages.cast<Map>().singleWhere(
        (item) => item['name'] == 'flutter',
      );
      final package = Directory.fromUri(
        configFile.uri.resolve(flutter['rootUri'] as String),
      );
      final executable =
          '${package.parent.parent.path}/bin/flutter${Platform.isWindows ? '.bat' : ''}';
      // The parent already loaded sqlite3.dll. The child owns distinct
      // build/hooks/native-assets directories in this temporary project.
      final childProject = Directory.systemTemp.createTempSync(
        'bil-preferences-probe-',
      );
      var childValidated = false;
      addTearDown(() {
        if (childValidated) {
          _deleteFixtureDirectory(childProject);
        } else {
          debugPrint(
            'PREFERENCES_DEADLINE_PROBE retained_failed_project=${childProject.path}',
          );
        }
      });
      final childTests = Directory(
        '${childProject.path}/test/features/dashboard',
      )..createSync(recursive: true);
      for (final name in [
        'dashboard_preferences_release_matrix_test.dart',
        'dashboard_preferences_fixture_lifecycle_cases.dart',
        'dashboard_preferences_fixture_host.dart',
        'dashboard_preferences_prepared_cases.dart',
      ]) {
        File(
          'test/features/dashboard/$name',
        ).copySync('${childTests.path}/$name');
      }
      File('${childProject.path}/pubspec.yaml').writeAsStringSync(
        File('pubspec.yaml').readAsStringSync().replaceFirst(
          'name: body_intelligence_log',
          'name: bil_preferences_deadline_probe',
        ),
      );
      Directory(
        '${childProject.path}/test/support',
      ).createSync(recursive: true);
      File('test/support/bil_waiting_indicators.dart').copySync(
        '${childProject.path}/test/support/bil_waiting_indicators.dart',
      );
      File('pubspec.lock').copySync('${childProject.path}/pubspec.lock');
      final childTool = Directory('${childProject.path}/.dart_tool')
        ..createSync();
      final childConfig = jsonDecode(configFile.readAsStringSync()) as Map;
      for (final entry in (childConfig['packages'] as List).cast<Map>()) {
        entry['rootUri'] = configFile.absolute.uri
            .resolve(entry['rootUri'] as String)
            .toString();
      }
      final rootPackage = Map<String, Object?>.from(
        (childConfig['packages'] as List).cast<Map>().singleWhere(
          (entry) => entry['name'] == 'body_intelligence_log',
        ),
      );
      rootPackage['name'] = 'bil_preferences_deadline_probe';
      rootPackage['rootUri'] = childProject.uri.toString();
      (childConfig['packages'] as List).add(rootPackage);
      Directory('${childProject.path}/lib').createSync();
      File(
        '${childTool.path}/package_config.json',
      ).writeAsStringSync(jsonEncode(childConfig));
      final graph =
          jsonDecode(File('.dart_tool/package_graph.json').readAsStringSync())
              as Map;
      final rootGraph = Map<String, Object?>.from(
        (graph['packages'] as List).cast<Map>().singleWhere(
          (entry) => entry['name'] == 'body_intelligence_log',
        ),
      );
      rootGraph['name'] = 'bil_preferences_deadline_probe';
      (graph['packages'] as List).add(rootGraph);
      graph['roots'] = ['bil_preferences_deadline_probe'];
      File(
        '${childTool.path}/package_graph.json',
      ).writeAsStringSync(jsonEncode(graph));
      final childEnvironment = <String, String>{
        'FLUTTER_SUPPRESS_ANALYTICS': 'true',
      };
      if (Platform.isWindows) {
        // sqlite3's documented hook source=system loads this same already-built
        // native DLL through PATH, without a download or parent-file overwrite.
        final binary = File('build/native_assets/windows/sqlite3.dll').absolute;
        expect(binary.existsSync(), isTrue);
        File('${childProject.path}/pubspec.yaml').writeAsStringSync(
          '\nhooks:\n  user_defines:\n    sqlite3:\n      source: system\n      name_windows: sqlite3\n',
          mode: FileMode.append,
        );
        childEnvironment['PATH'] =
            '${binary.parent.path};${Platform.environment['PATH'] ?? ''}';
      }
      final process = await Process.start(
        executable,
        [
          '--suppress-analytics',
          'test',
          '--no-pub',
          '--no-test-assets',
          '--machine',
          '--concurrency=1',
          '--dart-define=BIL_PREFERENCES_DEADLINE_PROBE=true',
          'test/features/dashboard/dashboard_preferences_release_matrix_test.dart',
        ],
        runInShell: Platform.isWindows,
        workingDirectory: childProject.path,
        environment: childEnvironment,
      );
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      var timedOut = false;
      Future<void> stopOwned() async {
        if (Platform.isWindows) {
          final killer = await Process.start('taskkill', [
            '/PID',
            '${process.pid}',
            '/T',
            '/F',
          ]);
          try {
            await killer.exitCode.timeout(const Duration(seconds: 5));
          } on TimeoutException {
            killer.kill();
          }
        } else {
          process.kill();
        }
      }

      final watchdog = Timer(const Duration(seconds: 60), () {
        timedOut = true;
        unawaited(stopOwned());
      });
      int? code;
      try {
        code = await process.exitCode.timeout(const Duration(seconds: 66));
      } finally {
        watchdog.cancel();
        if (code == null) await stopOwned();
      }
      final stdout = await output.timeout(const Duration(seconds: 5));
      final stderr = await errors.timeout(const Duration(seconds: 5));
      File('${childProject.path}/probe-events.jsonl').writeAsStringSync(stdout);
      File('${childProject.path}/probe-stderr.log').writeAsStringSync(stderr);

      expect(timedOut, isFalse, reason: stderr);
      expect(
        code,
        isNot(0),
        reason: 'The deliberately timed-out probe must fail.',
      );
      final events = <Map>[];
      for (final line in const LineSplitter().convert(stdout)) {
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map) events.add(decoded);
        } on FormatException {
          // Flutter may print a non-protocol tooling banner before JSON events.
        }
      }
      final errorEvents = events.where((e) => e['type'] == 'error').toList();
      expect(errorEvents, hasLength(1), reason: stdout + stderr);
      expect(
        errorEvents.single['error'],
        contains('Test timed out after 2 seconds'),
      );
      expect(stdout, isNot(contains('Reentrant call to runAsync')));
      expect(stdout, isNot(contains('PathAccessException')));
      expect(stdout, isNot(contains('_parentZone')));
      expect(
        stdout,
        contains('PREFERENCES_DEADLINE_PROBE retired_before_next_ui=true'),
      );
      expect(
        stdout,
        contains('PREFERENCES_DEADLINE_PROBE next_case_pass=true'),
      );
      final next = events
          .where(
            (e) =>
                e['type'] == 'testStart' &&
                (e['test'] as Map)['name'] ==
                    'deadline probe independent next case',
          )
          .single;
      final nextId = (next['test'] as Map)['id'];
      expect(
        events
            .where((e) => e['type'] == 'testDone' && e['testID'] == nextId)
            .single['result'],
        'success',
      );
      childValidated = true;
      debugPrint(
        'PREFERENCES_DEADLINE_PROBE expected_timeout_errors=1 '
        'next_case_pass=true process_exit=$code',
      );
    },
    timeout: const Timeout(Duration(seconds: 75)),
  );
}

void _registerActualDeadlineProbe() {
  testWidgets(
    'deadline probe pending native task',
    (tester) async {
      final directory = _fixtureDirectory();
      final file = File('${directory.path}/preferences.sqlite');
      final harness = await _openDeadlineFixture(tester, file);
      await _fixtureRunAsync(
        tester,
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      if (harness._retired) {
        debugPrint('PREFERENCES_DEADLINE_PROBE retired_before_next_ui=true');
        return;
      }
      fail('The probe should have reached its actual outer deadline.');
    },
    timeout: const Timeout(Duration(seconds: 2)),
  );

  testWidgets(
    'deadline probe independent next case',
    (tester) async {
      final directory = _fixtureDirectory();
      final file = File('${directory.path}/preferences.sqlite');
      _preparedPreferencesFixture!.materialize(file);
      final lease = _TrackedFixtureDatabase(file);
      try {
        await _fixtureRunAsync(tester, () async {
          final preferences = PreferencesRepository(lease.database);
          await preferences.set('next.after.deadline', 'isolated');
          expect(await preferences.get('next.after.deadline'), 'isolated');
        });
      } finally {
        await _finishHost(tester, lease.close, 'deadline next SQLite close');
      }
      file.deleteSync();
      expect(file.existsSync(), isFalse);
      debugPrint('PREFERENCES_DEADLINE_PROBE next_case_pass=true');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

Future<_PreferencesHarness> _openDeadlineFixture(
  WidgetTester tester,
  File file,
) async {
  _preparedPreferencesFixture!.materialize(file);
  final lease = _TrackedFixtureDatabase(file);
  final harness = _PreferencesHarness._(lease);
  _activePreferencesHarness[tester] = harness;
  addTearDown(() => harness.close(tester));
  try {
    await _fixtureRunAsync(tester, () async {
      await lease.database.customSelect('SELECT 1').get();
    });
    harness._checkOpen();
    return harness;
  } catch (error, stack) {
    return _preserveFailureDuringCleanup(
      error,
      stack,
      () => harness.close(tester),
    );
  }
}
