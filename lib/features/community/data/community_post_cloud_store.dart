import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/community_models.dart';
import '../domain/community_text_policy.dart';
import '../services/community_post_image_picker.dart';

abstract interface class CommunityPostStoreContract {
  Future<List<CommunityPost>> loadFeed({int limit = 40});

  Future<List<CommunityPost>> loadModerationQueue({int limit = 100});

  Future<void> publishText(String body);

  Future<void> publishWithImage(String body, CommunityPostImageDraft image);

  Future<void> delete(String postId);
}

abstract interface class CommunityPostPublishingReceiptContract {
  Future<String?> publishTextWithReceipt(String body);

  Future<String?> publishWithImageReceipt(
    String body,
    CommunityPostImageDraft image,
  );
}

abstract interface class CommunityPostMultiImagePublishingContract {
  Future<String?> publishWithImagesReceipt(
    String body,
    List<CommunityPostImageDraft> images,
  );
}

abstract interface class CommunityPostLookupContract {
  Future<List<CommunityPost>> loadPostsByIds(List<String> postIds);
}

abstract interface class CommunityPostPaginationContract {
  Future<CommunityFeedBatch> loadFeedPage({
    DateTime? before,
    String? beforeId,
    int limit = 40,
  });
}

/// Page through the signed-in member's posts, including pending or rejected
/// posts. It relies on the existing owner-only RLS policy and never creates a
/// second public feed surface.
abstract interface class CommunityPostAuthorPaginationContract {
  Future<CommunityFeedBatch> loadMyPostsPage({
    DateTime? before,
    String? beforeId,
    int limit = 40,
  });
}

abstract interface class CommunityPostProfilePaginationContract {
  Future<CommunityFeedBatch> loadProfilePostsPage({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  });
}

final class CommunityPostCloudStore
    implements
        CommunityPostStoreContract,
        CommunityPostPublishingReceiptContract,
        CommunityPostMultiImagePublishingContract,
        CommunityPostLookupContract,
        CommunityPostPaginationContract,
        CommunityPostAuthorPaginationContract,
        CommunityPostProfilePaginationContract {
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
  static const _postSelection =
      'id,author_id,body,created_at,media_object_path,media_mime_type,'
      'media_bytes,media_width,media_height,moderation_status,'
      'moderation_visibility,reviewed_at';

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async =>
      (await loadFeedPage(limit: limit)).posts;

  @override
  Future<CommunityFeedBatch> loadFeedPage({
    DateTime? before,
    String? beforeId,
    int limit = 40,
  }) async {
    if ((before == null) != (beforeId == null) ||
        (beforeId != null && !_uuid.hasMatch(beforeId))) {
      throw ArgumentError('Invalid Community feed cursor');
    }
    final boundedLimit = limit.clamp(1, 100);
    final selection = _client
        .from('bil_community_posts')
        .select(_postSelection)
        .eq('moderation_status', 'approved')
        .isFilter('deleted_at', null);
    final filtered = before == null
        ? selection
        : selection.or(
            'created_at.lt.${before.toUtc().toIso8601String()},'
            'and(created_at.eq.${before.toUtc().toIso8601String()},id.lt.$beforeId)',
          );
    final rows = await filtered
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(boundedLimit);
    final posts = await _hydrateVisibleRows(rows);
    final cursor = posts.isEmpty ? null : posts.last;
    return CommunityFeedBatch(
      posts: posts,
      hasMore: rows.length == boundedLimit,
      nextBefore: cursor?.createdAt,
      nextBeforeId: cursor?.id,
    );
  }

  @override
  Future<CommunityFeedBatch> loadMyPostsPage({
    DateTime? before,
    String? beforeId,
    int limit = 40,
  }) async {
    if ((before == null) != (beforeId == null) ||
        (beforeId != null && !_uuid.hasMatch(beforeId))) {
      throw ArgumentError('Invalid Community authored-post cursor');
    }
    final boundedLimit = limit.clamp(1, 100);
    final selection = _client
        .from('bil_community_posts')
        .select(_postSelection)
        .eq('author_id', _user.id)
        .isFilter('deleted_at', null);
    final filtered = before == null
        ? selection
        : selection.or(
            'created_at.lt.${before.toUtc().toIso8601String()},'
            'and(created_at.eq.${before.toUtc().toIso8601String()},id.lt.$beforeId)',
          );
    final rows = await filtered
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(boundedLimit);
    final posts = await _hydrateVisibleRows(rows);
    final cursor = posts.isEmpty ? null : posts.last;
    return CommunityFeedBatch(
      posts: posts,
      hasMore: rows.length == boundedLimit,
      nextBefore: cursor?.createdAt,
      nextBeforeId: cursor?.id,
    );
  }

  @override
  Future<CommunityFeedBatch> loadProfilePostsPage({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    if (!_uuid.hasMatch(userId) ||
        (before == null) != (beforeId == null) ||
        (beforeId != null && !_uuid.hasMatch(beforeId))) {
      throw ArgumentError('Invalid Community profile-post cursor');
    }
    final boundedLimit = limit.clamp(1, 60);
    final response = await _client.rpc(
      'bil_community_profile_posts_v1',
      params: {
        'p_user_id': userId,
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': boundedLimit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community profile posts');
    }
    final rows = response
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
    if (rows.length != response.length) {
      throw const FormatException('Invalid Community profile post row');
    }
    final posts = await _hydrateVisibleRows(rows);
    final cursor = posts.isEmpty ? null : posts.last;
    return CommunityFeedBatch(
      posts: posts,
      hasMore: rows.length == boundedLimit,
      nextBefore: cursor?.createdAt,
      nextBeforeId: cursor?.id,
    );
  }

  @override
  Future<List<CommunityPost>> loadPostsByIds(List<String> postIds) async {
    if (postIds.isEmpty) return const [];
    if (postIds.length > 100 || postIds.any((id) => !_uuid.hasMatch(id))) {
      throw ArgumentError.value(postIds, 'postIds');
    }
    final rows = await _client
        .from('bil_community_posts')
        .select(_postSelection)
        .inFilter('id', postIds);
    final hydrated = await _hydrateVisibleRows(rows);
    final byId = {for (final post in hydrated) post.id: post};
    return postIds
        .map((id) => byId[id])
        .whereType<CommunityPost>()
        .toList(growable: false);
  }

  Future<List<CommunityPost>> _hydrateVisibleRows(
    List<Map<String, dynamic>> rows,
  ) async {
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
    final postIds = validRows
        .map((row) => row['id'] as String)
        .toList(growable: false);
    final mediaByPost = await _loadPostMedia(postIds);
    final mediaPaths = <String>{
      for (final row in validRows)
        if (row['media_object_path'] case final String path) path,
      for (final items in mediaByPost.values)
        for (final item in items) item.objectPath,
    }.toList(growable: false);
    final signedUrls = await _signedUrls(mediaPaths);
    return validRows
        .map((row) {
          final profile = profilesById[row['author_id'] as String];
          final path = row['media_object_path'] as String?;
          final postId = row['id'] as String;
          final media = (mediaByPost[postId] ?? const <CommunityPostMedia>[])
              .map((item) => item.withUrl(signedUrls[item.objectPath]))
              .toList(growable: false);
          return CommunityPost.fromJson({
            ...row,
            'author_name': profile?['display_name'],
            'author_avatar_url': profile?['avatar_url'],
            'media_url': path == null ? null : signedUrls[path],
          }).withMedia(media);
        })
        .toList(growable: false);
  }

  @override
  Future<List<CommunityPost>> loadModerationQueue({int limit = 100}) async {
    final response = await _client.rpc(
      'bil_list_pending_community_posts',
      params: {'p_limit': limit.clamp(1, 200)},
    );
    if (response is! List) {
      throw const FormatException('Invalid community moderation queue');
    }
    final rows = response
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .where(_validPostRow)
        .toList(growable: false);
    final postIds = rows
        .map((row) => row['id'] as String)
        .toList(growable: false);
    final mediaByPost = await _loadPostMedia(postIds);
    final mediaPaths = <String>{
      for (final row in rows)
        if (row['media_object_path'] case final String path) path,
      for (final items in mediaByPost.values)
        for (final item in items) item.objectPath,
    }.toList(growable: false);
    final signedUrls = await _signedUrls(mediaPaths);
    return rows
        .map((row) {
          final path = row['media_object_path'] as String?;
          final postId = row['id'] as String;
          final media = (mediaByPost[postId] ?? const <CommunityPostMedia>[])
              .map((item) => item.withUrl(signedUrls[item.objectPath]))
              .toList(growable: false);
          return CommunityPost.fromJson({
            ...row,
            'media_url': path == null ? null : signedUrls[path],
          }).withMedia(media);
        })
        .toList(growable: false);
  }

  Future<Map<String, List<CommunityPostMedia>>> _loadPostMedia(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return const {};
    final response = await _client.rpc(
      'bil_community_post_media_v1',
      params: {'p_post_ids': postIds},
    );
    if (response is! List) {
      throw const FormatException('Invalid Community post media batch');
    }
    final requested = postIds.toSet();
    final grouped = <String, List<CommunityPostMedia>>{};
    for (final raw in response) {
      if (raw is! Map) {
        throw const FormatException('Invalid Community post media row');
      }
      final json = Map<String, dynamic>.from(raw);
      final postId = json['post_id'];
      if (postId is! String || !requested.contains(postId)) {
        throw const FormatException('Unexpected Community post media');
      }
      final media = CommunityPostMedia.fromJson(json);
      final items = grouped.putIfAbsent(postId, () => <CommunityPostMedia>[]);
      if (items.any(
        (item) =>
            item.position == media.position ||
            item.objectPath == media.objectPath,
      )) {
        throw const FormatException('Duplicate Community post media');
      }
      items.add(media);
    }
    for (final items in grouped.values) {
      items.sort((a, b) => a.position.compareTo(b.position));
      for (var index = 0; index < items.length; index++) {
        if (items[index].position != index) {
          throw const FormatException('Invalid Community post media order');
        }
      }
    }
    return {
      for (final entry in grouped.entries)
        entry.key: List<CommunityPostMedia>.unmodifiable(entry.value),
    };
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

  @override
  Future<void> publishText(String body) async {
    await publishTextWithReceipt(body);
  }

  @override
  Future<String?> publishTextWithReceipt(String body) async {
    final text = _validatedBody(body);
    if (text == null) return null;
    final postId = _uuidGenerator.v4();
    await _client.from('bil_community_posts').insert({
      'id': postId,
      'author_id': _user.id,
      'body': text,
      'visibility': 'community',
      'moderation_status': 'pending',
    });
    return postId;
  }

  @override
  Future<void> publishWithImage(
    String body,
    CommunityPostImageDraft image,
  ) async {
    await publishWithImageReceipt(body, image);
  }

  @override
  Future<String?> publishWithImageReceipt(
    String body,
    CommunityPostImageDraft image,
  ) => publishWithImagesReceipt(body, [image]);

  @override
  Future<String?> publishWithImagesReceipt(
    String body,
    List<CommunityPostImageDraft> images,
  ) async {
    final text = _validatedBody(body);
    if (text == null) return null;
    if (images.isEmpty || images.length > 4) {
      throw ArgumentError.value(images.length, 'images');
    }

    final validated = <CommunityPostImageDraft>[];
    for (final image in images) {
      validated.add(await validateCommunityPostImageAsync(image.bytes));
    }

    final postId = _uuidGenerator.v4();
    final media = <({String path, CommunityPostImageDraft image})>[];
    for (final image in validated) {
      final objectId = _uuidGenerator.v4();
      media.add((
        path: '${_user.id}/$postId/$objectId.${image.extension}',
        image: image,
      ));
    }

    final uploaded = <String>[];
    var postInserted = false;
    try {
      for (final item in media) {
        await _client.storage
            .from(_bucket)
            .uploadBinary(
              item.path,
              item.image.bytes,
              fileOptions: FileOptions(
                upsert: false,
                contentType: item.image.mimeType,
                cacheControl: '86400',
              ),
            );
        uploaded.add(item.path);
      }

      final first = media.first;
      await _client.from('bil_community_posts').insert({
        'id': postId,
        'author_id': _user.id,
        'body': text,
        'visibility': 'community',
        'moderation_status': 'pending',
        'media_url': null,
        'media_object_path': first.path,
        'media_mime_type': first.image.mimeType,
        'media_bytes': first.image.byteLength,
        'media_width': first.image.width,
        'media_height': first.image.height,
      });
      postInserted = true;

      final attached = await _client.rpc(
        'bil_set_my_community_post_media_v1',
        params: {
          'p_post_id': postId,
          'p_items': [
            for (final item in media)
              {
                'object_path': item.path,
                'mime_type': item.image.mimeType,
                'bytes': item.image.byteLength,
                'width': item.image.width,
                'height': item.image.height,
              },
          ],
        },
      );
      if (attached is! num || attached.toInt() != media.length) {
        throw const FormatException('Invalid Community media receipt');
      }
      return postId;
    } on Object {
      if (postInserted) {
        try {
          await _client.rpc(
            'bil_delete_community_post',
            params: {'p_post_id': postId},
          );
        } on Object {
          // The pending row remains non-public if rollback cannot complete.
        }
      }
      if (uploaded.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove(uploaded);
        } on Object {
          // Immutable UUID paths cannot overwrite another member's media.
        }
      }
      rethrow;
    }
  }

  @override
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
    }

    final mediaPaths = <String>{};
    if (mediaPath is String) mediaPaths.add(mediaPath);
    try {
      final response = await _client.rpc(
        'bil_my_community_post_media_paths_v1',
        params: {'p_post_id': postId},
      );
      if (response is! List ||
          response.any(
            (value) =>
                value is! String || !_validMediaPath(value, _user.id, postId),
          )) {
        throw const FormatException('Invalid Community media paths');
      }
      mediaPaths.addAll(response.cast<String>());
    } on FormatException {
      rethrow;
    } on Object {
      // Legacy single-image deletion remains safe if the batch helper fails.
    }

    final deleted = await _client.rpc(
      'bil_delete_community_post',
      params: {'p_post_id': postId},
    );
    if (deleted != true) {
      throw StateError('Post was not available to delete');
    }
    // The database mutation is authoritative. Storage cleanup is best effort:
    // stale images must never make a successfully deleted post look undeleted.
    if (mediaPaths.isNotEmpty) {
      try {
        await _client.storage
            .from(_bucket)
            .remove(mediaPaths.toList(growable: false));
      } on Object {
        // The row is already safely hidden; retrying storage cleanup is safe.
      }
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
    final moderationStatus = row['moderation_status'];
    if (id is! String ||
        !_uuid.hasMatch(id) ||
        authorId is! String ||
        !_uuid.hasMatch(authorId) ||
        body is! String ||
        body.trim().isEmpty ||
        body.length > 1200 ||
        _unsafeText.hasMatch(body) ||
        createdAt is! String ||
        DateTime.tryParse(createdAt) == null ||
        moderationStatus is! String ||
        !const {'pending', 'approved', 'rejected'}.contains(moderationStatus)) {
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
