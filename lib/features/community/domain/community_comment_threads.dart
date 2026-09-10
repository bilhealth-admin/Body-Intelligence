import 'community_models.dart';

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
