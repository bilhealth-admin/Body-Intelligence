import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../providers/user_profile_provider.dart';

const profilePhotoMaxBytes = 5 * 1024 * 1024;

typedef ProfilePhotoPicker =
    Future<XFile?> Function(List<XTypeGroup> acceptedTypeGroups);

class ProfilePhotoSaveResult {
  const ProfilePhotoSaveResult({
    required this.bytes,
    required this.cloudSynced,
    this.publicUrl,
  });

  final Uint8List bytes;
  final bool cloudSynced;
  final String? publicUrl;
}

final profilePhotoServiceProvider = Provider<ProfilePhotoService>((ref) {
  return ProfilePhotoService(ref.watch(preferencesRepositoryProvider));
});

class ProfilePhotoService {
  ProfilePhotoService(
    this._preferences, {
    String? Function()? authenticatedOwnerId,
    ProfilePhotoPicker? photoPicker,
  }) : _authenticatedOwnerId =
           authenticatedOwnerId ?? _currentAuthenticatedOwnerId,
       _photoPicker = photoPicker ?? _pickProfilePhoto;

  final PreferencesRepository _preferences;
  final String? Function() _authenticatedOwnerId;
  final ProfilePhotoPicker _photoPicker;

  Future<ProfilePhotoSaveResult?> chooseAndSave() async {
    final authenticatedOwnerAtSelection = _authenticatedOwnerId();
    final storageOwnerAtSelection = _preferences.localOwnerId;
    _requireAuthenticatedOwnerMatchesStorage(
      authenticatedOwnerAtSelection,
      storageOwnerAtSelection,
    );
    const types = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    );
    final file = await _photoPicker(const [types]);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > profilePhotoMaxBytes) {
      throw const ProfilePhotoTooLargeException();
    }
    final contentType = _contentType(file.name);
    return _saveForOwner(
      bytes,
      contentType: contentType,
      expectedStorageOwnerId: storageOwnerAtSelection,
      expectedAuthenticatedOwnerId: authenticatedOwnerAtSelection,
    );
  }

  Future<ProfilePhotoSaveResult> save(
    Uint8List bytes, {
    required String contentType,
  }) {
    final authenticatedOwnerId = _authenticatedOwnerId();
    final storageOwnerId = _preferences.localOwnerId;
    return _saveForOwner(
      bytes,
      contentType: contentType,
      expectedStorageOwnerId: storageOwnerId,
      expectedAuthenticatedOwnerId: authenticatedOwnerId,
    );
  }

  Future<ProfilePhotoSaveResult> _saveForOwner(
    Uint8List bytes, {
    required String contentType,
    required String? expectedStorageOwnerId,
    required String? expectedAuthenticatedOwnerId,
  }) async {
    if (bytes.isEmpty) throw const FormatException('Empty profile photo');
    if (bytes.lengthInBytes > profilePhotoMaxBytes) {
      throw const ProfilePhotoTooLargeException();
    }
    _requireAuthenticatedOwnerMatchesStorage(
      expectedAuthenticatedOwnerId,
      expectedStorageOwnerId,
    );
    // A picker or image decoder can remain open while the authenticated
    // account changes. Re-check the live identity before the first local
    // mutation so bytes selected for one member never enter another scope.
    _requireUnchangedOwners(
      expectedStorageOwnerId: expectedStorageOwnerId,
      expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
    );
    await _preferences.set('profilePhoto', base64Encode(bytes));
    _requireUnchangedOwners(
      expectedStorageOwnerId: expectedStorageOwnerId,
      expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
    );
    final publicUrl = await _upload(
      bytes,
      contentType: contentType,
      expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
    );
    return ProfilePhotoSaveResult(
      bytes: bytes,
      cloudSynced: publicUrl != null,
      publicUrl: publicUrl,
    );
  }

  Future<ProfilePhotoSaveResult?> syncStoredPhotoToCommunity() async {
    final expectedAuthenticatedOwnerId = _authenticatedOwnerId();
    final expectedStorageOwnerId = _preferences.localOwnerId;
    _requireAuthenticatedOwnerMatchesStorage(
      expectedAuthenticatedOwnerId,
      expectedStorageOwnerId,
    );
    final encoded = await _preferences.get('profilePhoto');
    if (encoded == null || encoded.isEmpty) return null;
    Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException {
      return null;
    }
    _requireUnchangedOwners(
      expectedStorageOwnerId: expectedStorageOwnerId,
      expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
    );
    if (expectedAuthenticatedOwnerId == null) {
      return ProfilePhotoSaveResult(bytes: bytes, cloudSynced: false);
    }
    final publicUrl = await _upload(
      bytes,
      contentType: 'image/jpeg',
      expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
    );
    return ProfilePhotoSaveResult(
      bytes: bytes,
      cloudSynced: publicUrl != null,
      publicUrl: publicUrl,
    );
  }

  Future<String?> _upload(
    Uint8List bytes, {
    required String contentType,
    required String? expectedAuthenticatedOwnerId,
  }) async {
    if (expectedAuthenticatedOwnerId == null) return null;
    if (!AppEnvironment.supabaseRuntimeReady) return null;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.id != expectedAuthenticatedOwnerId) {
      throw const ProfilePhotoIdentityChangedException();
    }
    try {
      final path = '${user.id}/avatar';
      await client.storage
          .from('profile-avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
              cacheControl: '3600',
            ),
          );
      _requireUnchangedOwners(
        expectedStorageOwnerId: expectedAuthenticatedOwnerId,
        expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
      );
      final version = DateTime.now().toUtc().millisecondsSinceEpoch;
      final publicUrl =
          '${client.storage.from('profile-avatars').getPublicUrl(path)}?v=$version';
      final updated = await client
          .from('bil_public_profiles')
          .update({
            'avatar_url': publicUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', user.id)
          .select('avatar_url')
          .maybeSingle();
      _requireUnchangedOwners(
        expectedStorageOwnerId: expectedAuthenticatedOwnerId,
        expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
      );
      // Storage can succeed before the member has created a Community
      // profile. Do not report cross-device sync until the public profile row
      // actually references the uploaded object; Community save retries it.
      if (updated == null || updated['avatar_url'] != publicUrl) return null;
      await _preferences.set('profilePhotoPublicUrl', publicUrl);
      return publicUrl;
    } on ProfilePhotoIdentityChangedException {
      rethrow;
    } on Object {
      // The chosen photo remains available locally. Community explicitly
      // reports that cloud sync did not complete and can retry on save.
      return null;
    }
  }

  void _requireAuthenticatedOwnerMatchesStorage(
    String? authenticatedOwnerId,
    String? storageOwnerId,
  ) {
    if (authenticatedOwnerId != null &&
        authenticatedOwnerId != storageOwnerId) {
      throw const ProfilePhotoIdentityChangedException();
    }
  }

  void _requireUnchangedOwners({
    required String? expectedStorageOwnerId,
    required String? expectedAuthenticatedOwnerId,
  }) {
    if (_preferences.localOwnerId != expectedStorageOwnerId ||
        _authenticatedOwnerId() != expectedAuthenticatedOwnerId) {
      throw const ProfilePhotoIdentityChangedException();
    }
  }

  static String? _currentAuthenticatedOwnerId() {
    if (!AppEnvironment.supabaseRuntimeReady) return null;
    final owner = Supabase.instance.client.auth.currentUser?.id.trim();
    return owner == null || owner.isEmpty ? null : owner;
  }

  static Future<XFile?> _pickProfilePhoto(
    List<XTypeGroup> acceptedTypeGroups,
  ) => openFile(acceptedTypeGroups: acceptedTypeGroups);

  static String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class ProfilePhotoTooLargeException implements Exception {
  const ProfilePhotoTooLargeException();
}

class ProfilePhotoIdentityChangedException implements Exception {
  const ProfilePhotoIdentityChangedException();
}
