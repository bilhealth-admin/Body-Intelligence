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
}
