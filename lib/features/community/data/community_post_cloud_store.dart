import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/community_models.dart';
import '../domain/community_text_policy.dart';
import '../services/community_post_image_picker.dart';

final class CommunityPostCloudStore {
  CommunityPostCloudStore(this._client, this._user);

  final SupabaseClient _client;
  final User _user;

  static const _bucket = 'community-post-images';
  static const _signedUrlLifetimeSeconds = 3600;
  static const _uuidGenerator = Uuid();
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final _unsafeText = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  Future<List<CommunityPost>> loadFeed({int limit = 40}) async {
    final rows = await _client
        .from('bil_community_posts')
        .select(
          'id,author_id,body,created_at,media_object_path,media_mime_type,media_bytes,media_width,media_height',
        )
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 100));
    final validRows = rows.where(_validPostRow).toList(growable: false);
    if (validRows.isEmpty) return const [];
    final authorIds = validRows
        .map((row) => row['author_id'] as String)
        .toSet()
        .toList(growable: false);
    final profiles = await _client
        .from('bil_public_profiles')
        .select('user_id,display_name,avatar_url')
        .inFilter('user_id', authorIds);
    final profilesById = <String, Map<String, dynamic>>{};
    for (final profile in profiles) {
      final userId = profile['user_id'];
      final displayName = profile['display_name'];
      final avatarUrl = profile['avatar_url'];
      if (userId is String &&
          _uuid.hasMatch(userId) &&
          displayName is String &&
          displayName.trim().isNotEmpty &&
          displayName.length <= 60 &&
          !_unsafeText.hasMatch(displayName) &&
          (avatarUrl == null || avatarUrl is String)) {
        profilesById[userId] = profile;
      }
    }
    final mediaPaths = validRows
        .map((row) => row['media_object_path'])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final signedUrls = await _signedUrls(mediaPaths);
    return validRows
        .map((row) {
          final profile = profilesById[row['author_id'] as String];
          final path = row['media_object_path'] as String?;
          return CommunityPost.fromJson({
            ...row,
            'author_name': profile?['display_name'],
            'author_avatar_url': profile?['avatar_url'],
            'media_url': path == null ? null : signedUrls[path],
          });
        })
        .toList(growable: false);
  }

  Future<Map<String, String>> _signedUrls(List<String> paths) async {
    if (paths.isEmpty) return const {};
    final urls = <String, String>{};
    try {
      final results = await _client.storage
          .from(_bucket)
          .createSignedUrlsResult(paths, _signedUrlLifetimeSeconds);
      for (final result in results) {
        if (result is! SignedUrlSuccess) continue;
        final uri = Uri.tryParse(result.signedUrl);
        if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
          urls[result.path] = result.signedUrl;
        }
      }
    } on Object {
      // A signing failure hides only the image; post text remains readable.
    }
    return urls;
  }

  Future<void> publishText(String body) async {
    final text = _validatedBody(body);
    if (text == null) return;
    await _client.from('bil_community_posts').insert({
      'author_id': _user.id,
      'body': text,
      'visibility': 'community',
    });
  }

  Future<void> publishWithImage(
    String body,
    CommunityPostImageDraft image,
  ) async {
    final text = _validatedBody(body);
    if (text == null) return;
    final validated = await validateCommunityPostImageAsync(image.bytes);
    final postId = _uuidGenerator.v4();
    final objectId = _uuidGenerator.v4();
    final path = '${_user.id}/$postId/$objectId.${validated.extension}';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          validated.bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: validated.mimeType,
            cacheControl: '86400',
          ),
        );
    try {
      await _client.from('bil_community_posts').insert({
        'id': postId,
        'author_id': _user.id,
        'body': text,
        'visibility': 'community',
        'media_url': null,
        'media_object_path': path,
        'media_mime_type': validated.mimeType,
        'media_bytes': validated.byteLength,
        'media_width': validated.width,
        'media_height': validated.height,
      });
    } on Object {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } on Object {
        // The immutable UUID path cannot overwrite another member's object.
      }
      rethrow;
    }
  }

  Future<void> delete(String postId) async {
    if (!_uuid.hasMatch(postId)) throw ArgumentError.value(postId, 'postId');
    final row = await _client
        .from('bil_community_posts')
        .select('id,author_id,media_object_path')
        .eq('id', postId)
        .eq('author_id', _user.id)
        .maybeSingle();
    if (row == null) throw StateError('Post was not available to delete');
    final mediaPath = row['media_object_path'];
    if (mediaPath != null) {
      if (mediaPath is! String ||
          !_validMediaPath(mediaPath, _user.id, postId)) {
        throw StateError('Post image path did not pass the ownership boundary');
      }
      await _client.storage.from(_bucket).remove([mediaPath]);
    }
    final changed = await _client
        .from('bil_community_posts')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'media_url': null,
          'media_object_path': null,
          'media_mime_type': null,
          'media_bytes': null,
          'media_width': null,
          'media_height': null,
        })
        .eq('id', postId)
        .eq('author_id', _user.id)
        .select('id');
    if (changed.length != 1) {
      throw StateError('Post was not available to delete');
    }
  }

  static String? _validatedBody(String body) {
    final text = body.trim();
    if (text.isEmpty) return null;
    if (text.length > 1200 || _unsafeText.hasMatch(text)) {
      throw const FormatException('Invalid community post body');
    }
    CommunityTextPolicy.enforce(text, surface: CommunityTextSurface.post);
    return text;
  }

  static bool _validPostRow(Map<String, dynamic> row) {
    final id = row['id'];
    final authorId = row['author_id'];
    final body = row['body'];
    final createdAt = row['created_at'];
    if (id is! String ||
        !_uuid.hasMatch(id) ||
        authorId is! String ||
        !_uuid.hasMatch(authorId) ||
        body is! String ||
        body.trim().isEmpty ||
        body.length > 1200 ||
        _unsafeText.hasMatch(body) ||
        createdAt is! String ||
        DateTime.tryParse(createdAt) == null) {
      return false;
    }
    final path = row['media_object_path'];
    final mime = row['media_mime_type'];
    final bytes = row['media_bytes'];
    final width = row['media_width'];
    final height = row['media_height'];
    final allNull =
        path == null &&
        mime == null &&
        bytes == null &&
        width == null &&
        height == null;
    if (allNull) return true;
    return path is String &&
        _validMediaPath(path, authorId, id) &&
        mime is String &&
        const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime) &&
        bytes is int &&
        bytes > 0 &&
        bytes <= communityPostImageMaxBytes &&
        width is int &&
        height is int &&
        width > 0 &&
        height > 0 &&
        width <= communityPostImageMaxDimension &&
        height <= communityPostImageMaxDimension &&
        width * height <= communityPostImageMaxPixels;
  }

  static bool _validMediaPath(String path, String authorId, String postId) {
    final parts = path.split('/');
    if (parts.length != 3 ||
        parts[0] != authorId ||
        parts[1] != postId ||
        !_uuid.hasMatch(parts[0]) ||
        !_uuid.hasMatch(parts[1])) {
      return false;
    }
    final dot = parts[2].lastIndexOf('.');
    if (dot <= 0 || dot == parts[2].length - 1) return false;
    final objectId = parts[2].substring(0, dot);
    final extension = parts[2].substring(dot + 1);
    return _uuid.hasMatch(objectId) &&
        const {'jpg', 'png', 'webp'}.contains(extension);
  }
}
