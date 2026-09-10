import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/services/display_name_sync.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PreferencesRepository preferences;
  late String? owner;
  late String remote;
  late DisplayNameSync sync;
  late List<String> writes;
  setUp(() {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'a',
    );
    preferences = PreferencesRepository(database);
    owner = 'a';
    remote = 'Old name';
    writes = [];
    sync = DisplayNameSync(
      preferences: preferences,
      currentOwnerId: () => owner,
      readRemote: (_) async => remote,
      writeRemote: (_, name) async {
        writes.add(name);
        remote = name;
        return true;
      },
    );
  });
  tearDown(() async {
    sync.dispose();
    await database.close();
  });

  test(
    'cloud name refreshes the local cache without a pending user edit',
    () async {
      await preferences.set('displayName', 'Cached name');
      await sync.synchronize();
      expect(await preferences.get('displayName'), 'Old name');
      expect(await preferences.get(DisplayNameSync.pendingKey), isNull);
      expect(writes, isEmpty);
    },
  );

  test(
    'explicit local name replaces the old cloud name and is acknowledged',
    () async {
      await preferences.setMany(DisplayNameSync.localEdit('  DR. KADEM  '));
      await sync.synchronize();
      expect(await preferences.get('displayName'), 'DR. KADEM');
      expect(remote, 'DR. KADEM');
      expect(await preferences.get(DisplayNameSync.pendingKey), isNull);
      await sync.synchronize();
      expect(await preferences.get('displayName'), 'DR. KADEM');
    },
  );

  test(
    'a late cloud read cannot revert an edit made while it was in flight',
    () async {
      final read = Completer<String?>();
      final started = Completer<void>();
      sync = DisplayNameSync(
        preferences: preferences,
        currentOwnerId: () => owner,
        readRemote: (_) {
          started.complete();
          return read.future;
        },
        writeRemote: (_, name) async {
          remote = name;
          return true;
        },
      );
      await preferences.set('displayName', 'Old name');
      final running = sync.synchronize();
      await started.future;
      await preferences.setMany(DisplayNameSync.localEdit('New name'));
      read.complete('Old cloud name');
      await running;
      expect(await preferences.get('displayName'), 'New name');
      expect(remote, 'New name');
    },
  );

  test('a newer edit is not acknowledged by an older write', () async {
    final firstWrite = Completer<bool>();
    final started = Completer<void>();
    sync = DisplayNameSync(
      preferences: preferences,
      currentOwnerId: () => owner,
      readRemote: (_) async => remote,
      writeRemote: (_, name) async {
        writes.add(name);
        if (writes.length == 1) {
          started.complete();
          await firstWrite.future;
        }
        remote = name;
        return true;
      },
    );
    await preferences.setMany(DisplayNameSync.localEdit('First'));
    final running = sync.synchronize();
    await started.future;
    await preferences.setMany(DisplayNameSync.localEdit('Second'));
    final queued = sync.synchronize();
    firstWrite.complete(true);
    await Future.wait([running, queued]);
    expect(writes, ['First', 'Second']);
    expect(remote, 'Second');
    expect(await preferences.get('displayName'), 'Second');
    expect(await preferences.get(DisplayNameSync.pendingKey), isNull);
  });

  test('offline or denied writes stay saved locally and retry later', () async {
    var offline = true;
    sync = DisplayNameSync(
      preferences: preferences,
      currentOwnerId: () => owner,
      readRemote: (_) async => remote,
      writeRemote: (_, name) async {
        if (offline) throw StateError('offline');
        remote = name;
        return true;
      },
    );
    await preferences.setMany(DisplayNameSync.localEdit('Offline name'));
    await sync.synchronize();
    expect(await preferences.get('displayName'), 'Offline name');
    expect(await preferences.get(DisplayNameSync.pendingKey), 'Offline name');
    offline = false;
    await sync.synchronize();
    expect(remote, 'Offline name');
    expect(await preferences.get(DisplayNameSync.pendingKey), isNull);
  });

  test('owner mismatch never sends another account local name', () async {
    await preferences.setMany(DisplayNameSync.localEdit('Private name'));
    owner = 'b';
    await sync.synchronize();
    expect(writes, isEmpty);
    expect(remote, 'Old name');
  });

  test('late account response is discarded after sign-out', () async {
    final read = Completer<String?>();
    final started = Completer<void>();
    sync = DisplayNameSync(
      preferences: preferences,
      currentOwnerId: () => owner,
      readRemote: (_) {
        started.complete();
        return read.future;
      },
      writeRemote: (_, name) async => true,
    );
    await preferences.set('displayName', 'Local name');
    final running = sync.synchronize();
    await started.future;
    owner = null;
    read.complete('Other response');
    await running;
    expect(await preferences.get('displayName'), 'Local name');
  });

  test('all user-facing name editors record durable local intent', () {
    for (final file in [
      'lib/features/profile/premium_profile_actions.dart',
      'lib/features/profile/profile_settings_actions.dart',
      'lib/features/onboarding/domain/onboarding_completion_service.dart',
      'lib/features/auth/account_gateway_page.dart',
      'lib/features/community/presentation/community_profile_page.dart',
    ]) {
      expect(
        File(file).readAsStringSync(),
        contains('DisplayNameSync.localEdit('),
        reason: file,
      );
    }
  });
}
