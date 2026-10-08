import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/community_models.dart';
import '../domain/community_polls.dart';

/// Hydrates moderation-only review material without widening ordinary feed
/// visibility. The server RPC remains the authority for moderator access.
class CommunityModerationContentLoader {
  const CommunityModerationContentLoader._();

  static const _batchSize = 100;
  static const _bucket = 'community-post-images';
  static const _signedUrlLifetimeSeconds = 900;

  static Future<List<CommunityPost>> hydrate({
    required SupabaseClient client,
    required List<CommunityPost> posts,
  }) async {
    if (posts.isEmpty) return posts;
    final ids = posts.map((post) => post.id).toList(growable: false);
    final mediaByPost = <String, List<CommunityPostMedia>>{};
    final pollByPost = <String, CommunityPoll>{};

    for (var offset = 0; offset < ids.length; offset += _batchSize) {
      final end = offset + _batchSize < ids.length
          ? offset + _batchSize
          : ids.length;
      final batch = ids.sublist(offset, end);
      await _loadMedia(client, batch, mediaByPost);
      await _loadPolls(client, batch, pollByPost);
    }

    return posts
        .map((post) {
          final media = mediaByPost[post.id];
          final withMedia = media == null ? post : post.withMedia(media);
          return withMedia.withPoll(pollByPost[post.id] ?? post.poll);
        })
        .toList(growable: false);
  }

  static Future<void> _loadMedia(
    SupabaseClient client,
    List<String> postIds,
    Map<String, List<CommunityPostMedia>> output,
  ) async {
    final response = await client.rpc(
      'bil_community_post_media_v1',
      params: {'p_post_ids': postIds},
    );
    if (response is! List) {
      throw const FormatException('Invalid moderation media batch');
    }
    final requested = postIds.toSet();
    final grouped = <String, List<CommunityPostMedia>>{};
    for (final raw in response) {
      if (raw is! Map) {
        throw const FormatException('Invalid moderation media row');
      }
      final json = Map<String, dynamic>.from(raw);
      final postId = json['post_id'];
      if (postId is! String || !requested.contains(postId)) {
        throw const FormatException('Unexpected moderation media row');
      }
      final item = CommunityPostMedia.fromJson(json);
      final list = grouped.putIfAbsent(postId, () => <CommunityPostMedia>[]);
      if (list.any(
        (existing) =>
            existing.position == item.position ||
            existing.objectPath == item.objectPath,
      )) {
        throw const FormatException('Duplicate moderation media row');
      }
      list.add(item);
    }

    final paths = <String>[];
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => a.position.compareTo(b.position));
      for (var index = 0; index < entry.value.length; index++) {
        if (entry.value[index].position != index) {
          throw const FormatException('Invalid moderation media order');
        }
        paths.add(entry.value[index].objectPath);
      }
    }

    final urls = <String, String>{};
    if (paths.isNotEmpty) {
      try {
        final results = await client.storage
            .from(_bucket)
            .createSignedUrlsResult(paths, _signedUrlLifetimeSeconds);
        for (final result in results) {
          if (result is SignedUrlSuccess) {
            final uri = Uri.tryParse(result.signedUrl);
            if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
              urls[result.path] = result.signedUrl;
            }
          }
        }
      } on Object {
        // Text and poll review remain available if image signing is transiently
        // unavailable. The moderator can refresh rather than receiving a fake URL.
      }
    }

    for (final entry in grouped.entries) {
      output[entry.key] = List<CommunityPostMedia>.unmodifiable(
        entry.value.map((item) => item.withUrl(urls[item.objectPath])),
      );
    }
  }

  static Future<void> _loadPolls(
    SupabaseClient client,
    List<String> postIds,
    Map<String, CommunityPoll> output,
  ) async {
    Object? response;
    try {
      response = await client.rpc(
        'bil_community_moderation_polls_v1',
        params: {'p_post_ids': postIds},
      );
    } on PostgrestException catch (error) {
      // owned.patch remains safe on BASE before BIL-00 applies the forward SQL
      // overlay. Any real authorization/data failure is still fail-closed.
      if (error.code == 'PGRST202' ||
          error.message.contains('bil_community_moderation_polls_v1')) {
        return;
      }
      rethrow;
    }
    if (response is! List) {
      throw const FormatException('Invalid moderation poll batch');
    }
    final requested = postIds.toSet();
    for (final raw in response) {
      if (raw is! Map) {
        throw const FormatException('Invalid moderation poll row');
      }
      final row = Map<String, dynamic>.from(raw);
      final postId = row['post_id'];
      final rawPoll = row['poll'];
      if (postId is! String || rawPoll is! Map || !requested.contains(postId)) {
        throw const FormatException('Unexpected moderation poll row');
      }
      final poll = CommunityPoll.fromJson(Map<String, dynamic>.from(rawPoll));
      if (poll.postId != postId || output.containsKey(postId)) {
        throw const FormatException('Invalid moderation poll receipt');
      }
      output[postId] = poll;
    }
  }
}
