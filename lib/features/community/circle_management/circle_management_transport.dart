import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/community_repository.dart';
import 'circle_management_models.dart';

class CircleOwnerIdentity {
  const CircleOwnerIdentity(this.ownerId, this.sessionId);

  final String? ownerId;
  final String? sessionId;

  bool sameAs(CircleOwnerIdentity other) =>
      ownerId == other.ownerId && sessionId == other.sessionId;
}

/// The transport seam is intentionally narrow. Tests implement it with local
/// synthetic data; the production adapter always uses the supplied repository.
abstract interface class CircleManagementTransport {
  Object get repositoryIdentity;
  CircleOwnerIdentity get owner;
  Stream<CircleOwnerIdentity> get ownerEvents;

  Future<T> runForOwner<T>({
    required String ownerId,
    required bool Function() isCurrentOwner,
    required Future<T> Function() action,
  });

  Future<Object?> rpc(String name, Map<String, dynamic> params);
  Future<void> upload(CircleMediaReference media, Uint8List bytes);
  Future<void> remove(CircleMediaReference media);
  Future<String> sign(CircleMediaReference media);
}

class RepositoryCircleManagementTransport implements CircleManagementTransport {
  RepositoryCircleManagementTransport(this.repository);

  final CommunityRepository repository;
  SupabaseClient get _client => repository.communitySocialClient;

  @override
  Object get repositoryIdentity => repository;

  @override
  CircleOwnerIdentity get owner => _identity(
    _client.auth.currentSession,
    fallbackOwner: _client.auth.currentUser?.id,
  );

  @override
  Stream<CircleOwnerIdentity> get ownerEvents =>
      _client.auth.onAuthStateChange.map((state) => _identity(state.session));

  @override
  Future<T> runForOwner<T>({
    required String ownerId,
    required bool Function() isCurrentOwner,
    required Future<T> Function() action,
  }) => repository.runForCommunityOwner(
    action,
    ownerId: ownerId,
    isCurrentOwner: isCurrentOwner,
  );

  @override
  Future<Object?> rpc(String name, Map<String, dynamic> params) async =>
      await _client.rpc(name, params: params);

  @override
  Future<void> upload(CircleMediaReference media, Uint8List bytes) async {
    await _client.storage
        .from(media.bucket)
        .uploadBinary(
          media.objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: media.mimeType,
            upsert: false,
            cacheControl: '60',
          ),
        );
  }

  @override
  Future<void> remove(CircleMediaReference media) async {
    await _client.storage.from(media.bucket).remove([media.objectPath]);
  }

  @override
  Future<String> sign(CircleMediaReference media) =>
      _client.storage.from(media.bucket).createSignedUrl(media.objectPath, 60);

  static CircleOwnerIdentity _identity(
    Session? session, {
    String? fallbackOwner,
  }) {
    String? sessionId;
    if (session != null) {
      try {
        final parts = session.accessToken.split('.');
        if (parts.length == 3) {
          final claims = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          );
          if (claims is Map && claims['session_id'] is String) {
            sessionId = claims['session_id'] as String;
          }
        }
      } on Object {
        // This local continuity marker is not token authentication. The SDK
        // and server still authenticate every request. Never log token data.
      }
    }
    return CircleOwnerIdentity(session?.user.id ?? fallbackOwner, sessionId);
  }
}
