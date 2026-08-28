import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../providers/user_profile_provider.dart';

const profilePhotoMaxBytes = 5 * 1024 * 1024;

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
  ProfilePhotoService(this._preferences);

  final PreferencesRepository _preferences;

  Future<ProfilePhotoSaveResult?> chooseAndSave() async {
    const types = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    );
    final file = await openFile(acceptedTypeGroups: [types]);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > profilePhotoMaxBytes) {
      throw const ProfilePhotoTooLargeException();
    }
    final contentType = _contentType(file.name);
    return save(bytes, contentType: contentType);
  }

  Future<ProfilePhotoSaveResult> save(
    Uint8List bytes, {
    required String contentType,
  }) async {
    if (bytes.isEmpty) throw const FormatException('Empty profile photo');
    if (bytes.lengthInBytes > profilePhotoMaxBytes) {
      throw const ProfilePhotoTooLargeException();
    }
    await _preferences.set('profilePhoto', base64Encode(bytes));
    final publicUrl = await _upload(bytes, contentType: contentType);
    return ProfilePhotoSaveResult(
      bytes: bytes,
      cloudSynced: publicUrl != null,
      publicUrl: publicUrl,
    );
  }

  Future<ProfilePhotoSaveResult?> syncStoredPhotoToCommunity() async {
    final encoded = await _preferences.get('profilePhoto');
    if (encoded == null || encoded.isEmpty) return null;
    Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException {
      return null;
    }
    final publicUrl = await _upload(bytes, contentType: 'image/jpeg');
    return ProfilePhotoSaveResult(
      bytes: bytes,
      cloudSynced: publicUrl != null,
      publicUrl: publicUrl,
    );
  }

  Future<String?> _upload(
    Uint8List bytes, {
    required String contentType,
  }) async {
    if (!AppEnvironment.supabaseRuntimeReady) return null;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;
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
      // Storage can succeed before the member has created a Community
      // profile. Do not report cross-device sync until the public profile row
      // actually references the uploaded object; Community save retries it.
      if (updated == null || updated['avatar_url'] != publicUrl) return null;
      await _preferences.set('profilePhotoPublicUrl', publicUrl);
      return publicUrl;
    } on Object {
      // The chosen photo remains available locally. Community explicitly
      // reports that cloud sync did not complete and can retry on save.
      return null;
    }
  }

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
