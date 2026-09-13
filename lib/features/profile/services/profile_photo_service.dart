import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/services/recoverable_image_picker.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../providers/user_profile_provider.dart';

/// Photos above this budget are compressed automatically before local storage
/// and upload. It is deliberately a target, not a rejection limit.
const profilePhotoCompressionTargetBytes = 1024 * 1024;
const _profilePhotoLargestEdge = 1600;
const _profilePhotoSmallestEdge = 720;

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

class _PreparedProfilePhoto {
  const _PreparedProfilePhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

Future<_PreparedProfilePhoto> _prepareProfilePhoto(
  Uint8List bytes, {
  required String contentType,
}) async {
  if (bytes.lengthInBytes <= profilePhotoCompressionTargetBytes) {
    return _PreparedProfilePhoto(bytes: bytes, contentType: contentType);
  }
  final compressed = await compute(_compressProfilePhoto, bytes);
  return _PreparedProfilePhoto(bytes: compressed, contentType: 'image/jpeg');
}

/// Runs away from the UI isolate. Real photos are never rejected merely for
/// being large; orientation is baked and the smallest high-quality JPEG under
/// the target is chosen. A valid but unusually detailed image still returns
/// its smallest candidate rather than blocking the member from saving it.
Uint8List _compressProfilePhoto(Uint8List source) {
  final decoded = image.decodeImage(source);
  if (decoded == null) throw const ProfilePhotoCompressionException();
  final normalized = image.bakeOrientation(decoded);
  final longest = normalized.width > normalized.height
      ? normalized.width
      : normalized.height;
  final initialEdge = longest > _profilePhotoLargestEdge
      ? _profilePhotoLargestEdge
      : longest;
  Uint8List? smallest;
  for (final edge in <int>{
    initialEdge,
    1280,
    1080,
    900,
    _profilePhotoSmallestEdge,
  }) {
    if (edge > longest || edge < _profilePhotoSmallestEdge) continue;
    final candidateImage = edge == longest
        ? normalized
        : normalized.width >= normalized.height
        ? image.copyResize(normalized, width: edge)
        : image.copyResize(normalized, height: edge);
    for (final quality in const [86, 78, 70, 62, 54]) {
      final candidate = Uint8List.fromList(
        image.encodeJpg(candidateImage, quality: quality),
      );
      if (smallest == null ||
          candidate.lengthInBytes < smallest.lengthInBytes) {
        smallest = candidate;
      }
      if (candidate.lengthInBytes <= profilePhotoCompressionTargetBytes) {
        return candidate;
      }
    }
  }
  return smallest ??
      Uint8List.fromList(image.encodeJpg(normalized, quality: 54));
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
    final prepared = await _prepareProfilePhoto(
      bytes,
      contentType: contentType,
    );
    _requireUnchangedOwners(
      expectedStorageOwnerId: expectedStorageOwnerId,
      expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
    );
    // A newly selected local image supersedes any cached cloud URL. This also
    // prevents a Community save from reusing or repeatedly refreshing a stale
    // avatar URL while the new upload is still pending.
    await _preferences.mutate(
      set: {'profilePhoto': base64Encode(prepared.bytes)},
      remove: const ['profilePhotoPublicUrl'],
    );
    _requireUnchangedOwners(
      expectedStorageOwnerId: expectedStorageOwnerId,
      expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
    );
    final publicUrl = await _upload(
      prepared.bytes,
      contentType: prepared.contentType,
      expectedAuthenticatedOwnerId: expectedAuthenticatedOwnerId,
    );
    return ProfilePhotoSaveResult(
      bytes: prepared.bytes,
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
    final cachedPublicUrl = (await _preferences.get(
      'profilePhotoPublicUrl',
    ))?.trim();
    if (cachedPublicUrl != null && cachedPublicUrl.isNotEmpty) {
      // The current image already has a public reference. Community profile
      // saves must not create a new cache-busting URL and flicker every avatar.
      return ProfilePhotoSaveResult(
        bytes: bytes,
        cloudSynced: true,
        publicUrl: cachedPublicUrl,
      );
    }
    final publicUrl = await _upload(
      bytes,
      contentType: _contentTypeForStoredBytes(bytes),
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

  static String _contentTypeForStoredBytes(Uint8List bytes) {
    if (bytes.lengthInBytes >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.lengthInBytes >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}

@Deprecated('Profile photos are compressed automatically instead of rejected.')
class ProfilePhotoTooLargeException implements Exception {
  const ProfilePhotoTooLargeException();
}

class ProfilePhotoCompressionException implements Exception {
  const ProfilePhotoCompressionException();
}

class ProfilePhotoIdentityChangedException implements Exception {
  const ProfilePhotoIdentityChangedException();
}
