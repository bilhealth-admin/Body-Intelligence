import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:body_intelligence_log/app/services/health_storage_directory_native.dart';
import 'package:body_intelligence_log/app/services/health_storage_privacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bil/health_storage_privacy');
  const protected = <String, Object?>{
    'scopeVersion': 1,
    'applicationSupportExcluded': true,
    'documentsExcluded': true,
    'preferencesExcluded': true,
  };
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory folder;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('bil-health-privacy-test-');
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await folder.delete(recursive: true);
  });

  test('non-iOS storage does not call an Apple platform channel', () async {
    var nativeCalls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      nativeCalls++;
      throw PlatformException(code: 'must_not_call');
    });
    final directory = await getProtectedApplicationSupportDirectory(
      privacy: BilHealthStoragePrivacy(isIos: false, channel: channel),
      directoryResolver: () async => folder,
    );
    expect(directory.path, folder.path);
    expect(nativeCalls, 0);
  });

  test(
    'delayed exclusion blocks health database creation until verified',
    () async {
      final permission = Completer<Map<String, Object?>>();
      var resolved = false;
      final file = File('${folder.path}/health.sqlite');
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'protectHealthStorage');
        expect(call.arguments, isNull); // No arbitrary path from Dart.
        return permission.future;
      });
      final opened =
          getProtectedApplicationSupportDirectory(
            privacy: BilHealthStoragePrivacy(isIos: true, channel: channel),
            directoryResolver: () async {
              resolved = true;
              return folder;
            },
          ).then((directory) {
            final database = sqlite3.open('${directory.path}/health.sqlite');
            database.execute('CREATE TABLE health(weight REAL NOT NULL)');
            database.execute('INSERT INTO health VALUES (72.5)');
            return database;
          });
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isFalse);
      expect(file.existsSync(), isFalse);
      permission.complete(protected);
      final database = await opened;
      expect(resolved, isTrue);
      expect(
        database.select('SELECT weight FROM health').single['weight'],
        72.5,
      );
      database.close();
    },
  );

  test(
    'all private storage parents and the version must be confirmed',
    () async {
      final invalid = <Object?>[
        null,
        <String, Object?>{},
        {...protected, 'scopeVersion': 2},
        {...protected, 'applicationSupportExcluded': false},
        {...protected, 'documentsExcluded': false},
        {...protected, 'preferencesExcluded': false},
        {...protected, 'applicationSupportExcluded': 'true'},
      ];
      var directoryCalls = 0;
      for (final response in invalid) {
        messenger.setMockMethodCallHandler(channel, (_) async => response);
        await expectLater(
          getProtectedApplicationSupportDirectory(
            privacy: BilHealthStoragePrivacy(isIos: true, channel: channel),
            directoryResolver: () async {
              directoryCalls++;
              return folder;
            },
          ),
          throwsA(isA<PlatformException>()),
        );
      }
      expect(directoryCalls, 0);
    },
  );

  test(
    'native failure preserves existing health bytes and can retry',
    () async {
      final original = File('${folder.path}/existing.sqlite');
      await original.writeAsBytes([1, 2, 3, 4], flush: true);
      var allowed = false;
      var directoryCalls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        if (!allowed) {
          throw PlatformException(code: 'health_backup_exclusion_failed');
        }
        return protected;
      });
      final privacy = BilHealthStoragePrivacy(isIos: true, channel: channel);
      Future<Directory> resolve() => getProtectedApplicationSupportDirectory(
        privacy: privacy,
        directoryResolver: () async {
          directoryCalls++;
          return folder;
        },
      );
      await expectLater(resolve(), throwsA(isA<PlatformException>()));
      expect(directoryCalls, 0);
      expect(await original.readAsBytes(), [1, 2, 3, 4]);
      allowed = true;
      expect((await resolve()).path, folder.path);
      expect(directoryCalls, 1);
      expect(await original.readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test(
    'simultaneous opens share one check then later opens reapply it',
    () async {
      var calls = 0;
      final first = Completer<Map<String, Object?>>();
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return calls == 1 ? first.future : protected;
      });
      final privacy = BilHealthStoragePrivacy(isIos: true, channel: channel);
      final a = privacy.ensureProtected();
      final b = privacy.ensureProtected();
      expect(identical(a, b), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      first.complete(protected);
      await Future.wait([a, b]);
      await privacy.ensureProtected();
      expect(calls, 2);
    },
  );

  test(
    'missing native bridge never opens or replaces the local database',
    () async {
      final original = File('${folder.path}/saved.sqlite');
      await original.writeAsBytes([7, 8, 9], flush: true);
      var called = false;
      await expectLater(
        getProtectedApplicationSupportDirectory(
          privacy: BilHealthStoragePrivacy(isIos: true, channel: channel),
          directoryResolver: () async {
            called = true;
            return folder;
          },
        ),
        throwsA(isA<MissingPluginException>()),
      );
      expect(called, isFalse);
      expect(await original.readAsBytes(), [7, 8, 9]);
    },
  );
  testWidgets('stalled native protection times out safely and retries', (
    tester,
  ) async {
    final stalled = Completer<Map<String, Object?>>();
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return calls == 1 ? stalled.future : protected;
    });
    final privacy = BilHealthStoragePrivacy(isIos: true, channel: channel);
    var directoryCalls = 0;
    final first = getProtectedApplicationSupportDirectory(
      privacy: privacy,
      directoryResolver: () async {
        directoryCalls++;
        return folder;
      },
    );
    final failed = expectLater(first, throwsA(isA<TimeoutException>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await failed;
    expect(directoryCalls, 0);
    expect(
      (await getProtectedApplicationSupportDirectory(
        privacy: privacy,
        directoryResolver: () async {
          directoryCalls++;
          return folder;
        },
      )).path,
      folder.path,
    );
    stalled.complete(protected); // Late reply cannot reopen the failed attempt.
    await tester.pump();
    expect(directoryCalls, 1);
    expect(calls, 2);
  });
}
