import 'dart:io';

import 'package:body_intelligence_log/app/services/local_recovery_service.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late Directory recoveryDirectory;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    recoveryDirectory = await Directory.systemTemp.createTemp(
      'bil-recovery-test-',
    );
  });

  tearDown(() async {
    await database.close();
    if (recoveryDirectory.existsSync()) {
      await recoveryDirectory.delete(recursive: true);
    }
  });

  Future<void> seedUser() async {
    await UserProfileRepository(database).save(
      gender: 'male',
      age: 34,
      height: 181,
      currentWeight: 94,
      targetWeight: 85,
      activityLevel: 'moderate',
      exercises: true,
    );
    await PreferencesRepository(database).set('displayName', 'Kadem');
    await PreferencesRepository(database).set('forceOnboarding', 'false');
  }

  test(
    'reset creates a valid snapshot and restore returns local data',
    () async {
      await seedUser();
      final service = LocalRecoveryService(
        database,
        directoryResolver: () async => recoveryDirectory,
      );

      await service.resetWithRecovery();
      expect(await database.select(database.userProfile).get(), isEmpty);
      expect(await service.hasValidSnapshot(), isTrue);

      await service.restore();
      final profile = await database.select(database.userProfile).getSingle();
      expect(profile.currentWeight, 94);
      expect(await PreferencesRepository(database).get('displayName'), 'Kadem');
      expect(
        await PreferencesRepository(database).get('forceOnboarding'),
        'false',
      );
    },
  );

  test('snapshot failure never clears existing local data', () async {
    await seedUser();
    final service = LocalRecoveryService(
      database,
      directoryResolver: () async => throw FileSystemException('blocked'),
    );

    await expectLater(service.resetWithRecovery(), throwsA(isA<Exception>()));
    expect(await database.select(database.userProfile).get(), hasLength(1));
  });

  test('invalid snapshot is rejected without changing current data', () async {
    await seedUser();
    final recovery = Directory(
      '${recoveryDirectory.path}${Platform.pathSeparator}recovery',
    )..createSync();
    File(
      '${recovery.path}${Platform.pathSeparator}bil_local_recovery_v1.sqlite',
    ).writeAsStringSync('not a database');
    final service = LocalRecoveryService(
      database,
      directoryResolver: () async => recoveryDirectory,
    );

    expect(await service.hasValidSnapshot(), isFalse);
    await expectLater(service.restore(), throwsA(isA<Exception>()));
    expect(await database.select(database.userProfile).get(), hasLength(1));
  });
}
