import 'community_models.dart';

class CommunityCommentThread {
  const CommunityCommentThread({
    required this.root,
    required this.replies,
    required this.replyCount,
  });

  final CommunityComment root;
  final List<CommunityComment> replies;
  final int replyCount;

  bool get hasHiddenReplies => replies.length < replyCount;

  CommunityCommentThread copyWith({
    CommunityComment? root,
    List<CommunityComment>? replies,
    int? replyCount,
  }) => CommunityCommentThread(
    root: root ?? this.root,
    replies: replies == null
        ? this.replies
        : List<CommunityComment>.unmodifiable(replies),
    replyCount: replyCount ?? this.replyCount,
  );

  factory CommunityCommentThread.fromJson(Map<String, dynamic> json) {
    final rawRoot = json['root'];
    final rawReplies = json['replies'];
    final rawReplyCount = json['reply_count'];
    final rawRootId = json['root_id'];
    final rawRootCreatedAt = json['root_created_at'];

    if (rawRoot is! Map ||
        rawReplies is! List ||
        rawReplyCount is! num ||
        rawReplyCount < 0 ||
        rawReplyCount % 1 != 0 ||
        rawRootId is! String ||
        rawRootCreatedAt is! String) {
      throw const FormatException('Invalid Community comment thread');
    }

    final root = CommunityComment.fromJson(
      Map<String, dynamic>.from(rawRoot),
    );
    final rootCreatedAt = DateTime.tryParse(rawRootCreatedAt);
    if (rootCreatedAt == null ||
        root.id != rawRootId ||
        root.parentId != null ||
        root.createdAt.toUtc() != rootCreatedAt.toUtc() ||
        root.replyCount != rawReplyCount.toInt()) {
      throw const FormatException('Invalid Community comment thread root');
    }

    final replies = rawReplies.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid Community thread reply');
      }
      final reply = CommunityComment.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (reply.parentId != root.id || reply.replyCount != 0) {
        throw const FormatException('Invalid Community thread reply');
      }
      return reply;
    }).toList(growable: false);

    if (replies.length > root.replyCount) {
      throw const FormatException('Invalid Community reply count');
    }

    return CommunityCommentThread(
      root: root,
      replies: List<CommunityComment>.unmodifiable(replies),
      replyCount: root.replyCount,
    );
  }
}


/// Social v2 stores one-level threads. Transport order is chronological and
/// must remain separate from display order and from locally added comments.
List<CommunityComment> communityCommentsInThreadOrder(
  Iterable<CommunityComment> comments,
) {
  final unique =
      {for (final comment in comments) comment.id: comment}.values.toList()
        ..sort((a, b) {
          final byTime = a.createdAt.compareTo(b.createdAt);
          return byTime == 0 ? a.id.compareTo(b.id) : byTime;
        });
  final replies = <String, List<CommunityComment>>{};
  for (final comment in unique) {
    final parentId = comment.parentId;
    if (parentId != null) (replies[parentId] ??= []).add(comment);
  }
  final result = <CommunityComment>[];
  final emitted = <String>{};
  for (final root in unique.where((comment) => comment.parentId == null)) {
    emitted.add(root.id);
    result.add(root);
    for (final reply in replies[root.id] ?? const <CommunityComment>[]) {
      if (emitted.add(reply.id)) result.add(reply);
    }
  }
  // A visible reply can arrive before its parent at a page boundary. Do not
  // invent the parent's identity or permanently hide this authorized row.
  result.addAll(unique.where((comment) => emitted.add(comment.id)));
  return List.unmodifiable(result);
}
