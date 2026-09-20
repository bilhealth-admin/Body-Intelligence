import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/services/recoverable_image_picker.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../providers/user_profile_provider.dart';

const profilePhotoMaxBytes = 5 * 1024 * 1024;

typedef ProfilePhotoPicker =
    Future<XFile?> Function(List<XTypeGroup> acceptedTypeGroups);
typedef RecoveredProfilePhotoPicker = Future<XFile?> Function();
typedef ProfilePhotoCloudRemover = Future<void> Function(String ownerId);

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
    RecoveredProfilePhotoPicker? recoveredPhotoPicker,
    ProfilePhotoCloudRemover? cloudRemover,
  }) : _authenticatedOwnerId =
           authenticatedOwnerId ?? _currentAuthenticatedOwnerId,
       _photoPicker = photoPicker ?? _pickProfilePhoto,
       _recoveredPhotoPicker =
           recoveredPhotoPicker ?? _takeRecoveredProfilePhoto,
       _cloudRemover = cloudRemover ?? _removeCloudProfilePhoto;

  final PreferencesRepository _preferences;
  final String? Function() _authenticatedOwnerId;
  final ProfilePhotoPicker _photoPicker;
  final RecoveredProfilePhotoPicker _recoveredPhotoPicker;
  final ProfilePhotoCloudRemover _cloudRemover;

  Future<ProfilePhotoSaveResult?> chooseAndSave({
    bool recoveredOnly = false,
  }) async {
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
    // An automatic Android process-death resume must never open a fresh
    // picker when its one-shot recovered result is gone. This prevents a stale
    // route query from manufacturing a new user action or looping.
    final file = recoveredOnly
        ? await _recoveredPhotoPicker()
        : await _photoPicker(const [types]);
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

  Future<void> remove() async {
    final expectedAuthenticatedOwnerId = _authenticatedOwnerId();
    final expectedStorageOwnerId = _preferences.localOwnerId;
    _requireAuthenticatedOwnerMatchesStorage(
      expectedAuthenticatedOwnerId,
      expectedStorageOwnerId,
    );
    _requireUnchangedOwners(
      expectedStorageOwnerId: expectedStorageOwnerId,
      expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
    );
    if (expectedAuthenticatedOwnerId != null) {
      // Keep the local copy until both cloud references are removed. A failed
      // network request must not make the action appear complete while the
      // public avatar remains accessible on another device.
      await _cloudRemover(expectedAuthenticatedOwnerId);
      _requireUnchangedOwners(
        expectedStorageOwnerId: expectedStorageOwnerId,
        expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
      );
    }
    await _preferences.removeMany(const [
      'profilePhoto',
      'profilePhotoPublicUrl',
    ]);
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

  static Future<void> _removeCloudProfilePhoto(String ownerId) async {
    if (!AppEnvironment.supabaseRuntimeReady) return;
    final client = Supabase.instance.client;
    if (client.auth.currentUser?.id != ownerId) {
      throw const ProfilePhotoIdentityChangedException();
    }
    final path = '$ownerId/avatar';
    await client.storage.from('profile-avatars').remove([path]);
    if (client.auth.currentUser?.id != ownerId) {
      throw const ProfilePhotoIdentityChangedException();
    }
    await client
        .from('bil_public_profiles')
        .update({
          'avatar_url': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', ownerId);
  }

  static Future<XFile?> _pickProfilePhoto(List<XTypeGroup> acceptedTypeGroups) {
    // file_selector is reliable on desktop, but on iOS its document picker
    // can dismiss without returning an asset for a photo-library selection.
    // image_picker uses Apple's native PHPicker on iOS and the system picker
    // on Android, so the Add photo action always presents a real photo flow.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      return BilRecoverableImagePicker.instance.pickImage(
        purpose: BilImagePickerPurpose.profilePhoto,
        source: image_picker.ImageSource.gallery,
        imageQuality: 90,
      );
    }
    return openFile(acceptedTypeGroups: acceptedTypeGroups);
  }

  static Future<XFile?> _takeRecoveredProfilePhoto() =>
      BilRecoverableImagePicker.instance.takeRecoveredImage(
        BilImagePickerPurpose.profilePhoto,
      );

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
