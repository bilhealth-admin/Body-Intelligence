import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../../app/services/health_storage_directory_native.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../domain/community_models.dart';
import '../../../app/environment/app_environment.dart';

/// Content cache, never authorization. Fresh visible IDs are required before
/// reading cached posts. Signed capabilities and credentials are not stored.
class CommunityFeedCache {
  CommunityFeedCache({this._directory, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  static final instance = CommunityFeedCache();
  final Directory? _directory;
  final DateTime Function() _clock;
  final Set<String> _deleted = {};
  String? _owner;
  int _epoch = 0;
  bool _bound = false;
  Future<void> _clearing = Future.value();
  Future<void> _writes = Future.value();
  StreamSubscription<AuthState>? _auth;

  void bindOwner(String? owner) {
    if (_auth == null && AppEnvironment.supabaseRuntimeReady) {
      try {
        _auth = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
          if (state.session == null &&
              state.event != AuthChangeEvent.signedOut) {
            return;
          }
          bindOwner(state.session?.user.id);
        });
      } on Object {
        /* Isolated caches have no native auth session. */
      }
    }
    if (!_bound) {
      _bound = true;
      _owner = owner;
      return;
    }
    if (_owner == owner) return;
    _owner = owner;
    _epoch++;
    final before = _clearing;
    _clearing = () async {
      await before;
      final root = await _root(wait: false);
      if (await root.exists()) await root.delete(recursive: true);
    }().catchError((Object _) {});
  }

  Future<Directory> _root({bool wait = true}) async {
    if (wait) await _clearing;
    return _directory ??
        Directory(
          '${(await getProtectedApplicationSupportDirectory()).path}/bil_feed_v1',
        );
  }

  String _key(String owner, String scope) =>
      sha256.convert(utf8.encode('$owner|$scope')).toString();

  Future<void> save(String owner, String scope, List<CommunityPost> posts) {
    final epoch = _epoch;
    return _writes = _writes.then((_) async {
      if (epoch != _epoch || _owner != owner) return;
      await _save(owner, scope, posts);
    });
  }

  Future<void> _save(
    String owner,
    String scope,
    List<CommunityPost> posts,
  ) async {
    final epoch = _epoch;
    if (_owner != owner) return;
    try {
      final root = await _root();
      await root.create(recursive: true);
      final bytes = utf8.encode(
        jsonEncode({
          'saved': _clock().millisecondsSinceEpoch,
          'rows': [
            for (final post in posts.take(40))
              if (!_deleted.contains(post.id)) _encode(post),
          ],
        }),
      );
      if (bytes.length > 2 * 1024 * 1024 ||
          epoch != _epoch ||
          _owner != owner) {
        return;
      }
      final target = File('${root.path}/${_key(owner, scope)}.json');
      final temporary = File('${target.path}.$epoch.partial');
      await temporary.writeAsBytes(bytes, flush: true);
      if (epoch != _epoch || _owner != owner) {
        await temporary.delete();
        return;
      }
      await temporary.rename(target.path);
      final files = await root
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.json'))
          .cast<File>()
          .toList();
      if (files.length > 8) {
        for (final file
            in files
                .where((file) => file.path != target.path)
                .take(files.length - 8)) {
          await file.delete();
        }
      }
    } on Object {
      /* Cache failure does not change server data. */
    }
  }

  Future<List<CommunityPost>> readAuthorized(
    String owner,
    String scope,
    List<String> visibleIds,
  ) async {
    if (_owner != owner || visibleIds.isEmpty) return const [];
    final epoch = _epoch;
    try {
      final file = File('${(await _root()).path}/${_key(owner, scope)}.json');
      if (await file.length() > 2 * 1024 * 1024) return const [];
      final data = jsonDecode(await file.readAsString());
      if (data is! Map ||
          data['saved'] is! int ||
          data['rows'] is! List ||
          _clock().millisecondsSinceEpoch - (data['saved'] as int) >
              const Duration(hours: 1).inMilliseconds) {
        return const [];
      }
      if (epoch != _epoch || _owner != owner) return const [];
      final byId = <String, CommunityPost>{};
      for (final row in data['rows'] as List) {
        final post = CommunityPost.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        if (!_deleted.contains(post.id) && visibleIds.contains(post.id)) {
          // The private bucket requires a real signed capability token.
          // Constructing /object/sign/<path> without that token creates a
          // guaranteed-broken image request (and leaks an object path into
          // device/network logs). Keep the authorized cached text and media
          // metadata; a fresh server hydration attaches signed URLs later.
          byId[post.id] = post.withMedia([
            for (final media in post.mediaItems) media.withUrl(null),
          ]);
        }
      }
      return [
        for (final id in visibleIds)
          if (byId[id] != null) byId[id]!,
      ];
    } on Object {
      return const [];
    }
  }

  void invalidatePost(String id) {
    _deleted.add(id);
  }

  Map<String, Object?> _encode(CommunityPost post) => {
    'id': post.id, 'author_id': post.authorId, 'body': post.body,
    'created_at': post.createdAt.toUtc().toIso8601String(),
    'author_name': post.authorName,
    'author_avatar_url': _publicAvatar(post.authorAvatarUrl),
    'moderation_status': post.moderationStatus.name,
    'moderation_visibility': switch (post.moderationVisibility) {
      CommunityPostModerationVisibility.visible => 'visible',
      CommunityPostModerationVisibility.hiddenByModerator =>
        'hidden_by_moderator',
      CommunityPostModerationVisibility.removedByModerator =>
        'removed_by_moderator',
    },
    'reviewed_at': post.reviewedAt?.toUtc().toIso8601String(),
    'like_count': post.likeCount, 'liked': post.liked,
    'comment_count': post.commentCount, 'saved': post.saved,
    'author_handle': post.authorHandle,
    'author_relationship': post.authorRelationship?.name,
    'author_can_request': post.authorCanRequest,
    'location_label': post.locationLabel,
    // The live refresh restores media capabilities and optional poll data.
    'media': [
      for (final media in post.mediaItems)
        {
          'media_position': media.position,
          'object_path': media.objectPath,
          'mime_type': media.mimeType,
          'bytes': media.bytes,
          'width': media.width,
          'height': media.height,
        },
    ],
  };
  String? _publicAvatar(String? raw) {
    final uri = Uri.tryParse(raw ?? '');
    return uri != null &&
            uri.scheme == 'https' &&
            uri.queryParameters.keys.every((key) => key == 'v') &&
            uri.path.contains('/storage/v1/object/public/profile-avatars/')
        ? raw
        : null;
  }
}
