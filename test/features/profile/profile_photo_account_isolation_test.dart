import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/services/profile_photo_service.dart';
import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'guest photo save stays local and succeeds without cloud identity',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final preferences = PreferencesRepository(database);
      final service = ProfilePhotoService(
        preferences,
        authenticatedOwnerId: () => null,
      );
      final bytes = Uint8List.fromList(const [1, 2, 3, 4]);

      final result = await service.save(bytes, contentType: 'image/png');

      expect(result.bytes, bytes);
      expect(result.cloudSynced, isFalse);
      expect(result.publicUrl, isNull);
      expect(await preferences.get('profilePhoto'), base64Encode(bytes));
    },
  );

  test(
    'offline owner-scoped photo save and sync stay local without auth',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      );
      addTearDown(database.close);
      final preferences = PreferencesRepository(database);
      final service = ProfilePhotoService(
        preferences,
        authenticatedOwnerId: () => null,
      );
      final bytes = Uint8List.fromList(const [11, 12, 13, 14]);

      final saved = await service.save(bytes, contentType: 'image/png');
      final synced = await service.syncStoredPhotoToCommunity();

      expect(saved.bytes, bytes);
      expect(saved.cloudSynced, isFalse);
      expect(saved.publicUrl, isNull);
      expect(synced, isNotNull);
      expect(synced!.bytes, bytes);
      expect(synced.cloudSynced, isFalse);
      expect(synced.publicUrl, isNull);
      expect(await preferences.get('profilePhoto'), base64Encode(bytes));
      expect(await preferences.get('profilePhotoPublicUrl'), isNull);
    },
  );

  test('guest removal clears local photo and cached public URL', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    await preferences.setMany(const {
      'profilePhoto': 'encoded-photo',
      'profilePhotoPublicUrl': 'https://example.test/avatar',
    });
    final service = ProfilePhotoService(
      preferences,
      authenticatedOwnerId: () => null,
    );

    await service.remove();

    expect(await preferences.get('profilePhoto'), isNull);
    expect(await preferences.get('profilePhotoPublicUrl'), isNull);
  });

  test(
    'authenticated removal clears cloud before local profile photo',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      );
      addTearDown(database.close);
      final preferences = PreferencesRepository(database);
      await preferences.setMany(const {
        'profilePhoto': 'encoded-photo',
        'profilePhotoPublicUrl': 'https://example.test/avatar',
      });
      String? removedOwner;
      final service = ProfilePhotoService(
        preferences,
        authenticatedOwnerId: () => 'owner-a',
        cloudRemover: (ownerId) async {
          removedOwner = ownerId;
          expect(await preferences.get('profilePhoto'), 'encoded-photo');
          expect(
            await preferences.get('profilePhotoPublicUrl'),
            'https://example.test/avatar',
          );
        },
      );

      await service.remove();

      expect(removedOwner, 'owner-a');
      expect(await preferences.get('profilePhoto'), isNull);
      expect(await preferences.get('profilePhotoPublicUrl'), isNull);
    },
  );

  test('cloud removal failure preserves both local profile keys', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-a',
    );
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    await preferences.setMany(const {
      'profilePhoto': 'encoded-photo',
      'profilePhotoPublicUrl': 'https://example.test/avatar',
    });
    final service = ProfilePhotoService(
      preferences,
      authenticatedOwnerId: () => 'owner-a',
      cloudRemover: (_) => Future<void>.error(StateError('offline')),
    );

    await expectLater(service.remove(), throwsA(isA<StateError>()));

    expect(await preferences.get('profilePhoto'), 'encoded-photo');
    expect(
      await preferences.get('profilePhotoPublicUrl'),
      'https://example.test/avatar',
    );
  });

  test('mismatched authenticated owner performs no local mutation', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-a',
    );
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    final service = ProfilePhotoService(
      preferences,
      authenticatedOwnerId: () => 'owner-b',
    );

    await expectLater(
      service.save(
        Uint8List.fromList(const [5, 6, 7]),
        contentType: 'image/jpeg',
      ),
      throwsA(isA<ProfilePhotoIdentityChangedException>()),
    );

    expect(await preferences.get('profilePhoto'), isNull);
    expect(await preferences.get('profilePhotoPublicUrl'), isNull);
  });

  test('account switch while picker is open performs no mutation', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-a',
    );
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    var authenticatedOwner = 'owner-a';
    final service = ProfilePhotoService(
      preferences,
      authenticatedOwnerId: () => authenticatedOwner,
      photoPicker: (_) async {
        authenticatedOwner = 'owner-b';
        return XFile.fromData(
          Uint8List.fromList(const [8, 9, 10]),
          name: 'avatar.png',
          mimeType: 'image/png',
        );
      },
    );

    await expectLater(
      service.chooseAndSave(),
      throwsA(isA<ProfilePhotoIdentityChangedException>()),
    );

    expect(await preferences.get('profilePhoto'), isNull);
    expect(await preferences.get('profilePhotoPublicUrl'), isNull);
  });

  test('recovery-only profile save never falls back to a new picker', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    var normalPickerCalls = 0;
    var recoveryCalls = 0;
    final service = ProfilePhotoService(
      preferences,
      authenticatedOwnerId: () => null,
      photoPicker: (_) async {
        normalPickerCalls += 1;
        return XFile.fromData(
          Uint8List.fromList(const [20, 21, 22]),
          name: 'unexpected.png',
          mimeType: 'image/png',
        );
      },
      recoveredPhotoPicker: () async {
        recoveryCalls += 1;
        return null;
      },
    );

    final result = await service.chooseAndSave(recoveredOnly: true);

    expect(result, isNull);
    expect(recoveryCalls, 1);
    expect(normalPickerCalls, 0);
    expect(await preferences.get('profilePhoto'), isNull);
  });

  test('recovery-only profile save persists the recovered file once', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    final bytes = Uint8List.fromList(const [30, 31, 32, 33]);
    final service = ProfilePhotoService(
      preferences,
      authenticatedOwnerId: () => null,
      photoPicker: (_) => throw StateError('must not open a new picker'),
      recoveredPhotoPicker: () async =>
          XFile.fromData(bytes, name: 'recovered.png', mimeType: 'image/png'),
    );

    final result = await service.chooseAndSave(recoveredOnly: true);

    expect(result, isNotNull);
    expect(result!.bytes, bytes);
    expect(result.cloudSynced, isFalse);
    expect(await preferences.get('profilePhoto'), base64Encode(bytes));
  });
}
