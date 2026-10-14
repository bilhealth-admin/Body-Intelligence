import '../../notifications/domain/community_deep_link.dart';
import '../domain/community_comment_threads.dart';
import '../domain/community_models.dart';
import '../services/community_owner_operation.dart';
import 'community_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityNotificationCommentPage {
  const CommunityNotificationCommentPage({
    required this.comments,
    required this.hasMore,
    this.after,
    this.afterId,
  });
  final List<CommunityComment> comments;
  final bool hasMore;
  final DateTime? after;
  final String? afterId;
}

class CommunityNotificationCommentFocus {
  const CommunityNotificationCommentFocus({
    required this.thread,
    required this.commentId,
  });
  final CommunityCommentThread thread;
  final String commentId;
}

/// Uses existing server-authorized readers. Social tables intentionally deny
/// direct SELECT; a client must not widen RLS merely to jump to a comment.
class CommunityNotificationContentLoader {
  const CommunityNotificationContentLoader(this.repository);
  final CommunityRepository repository;

  static bool _missingThreads(Object error) =>
      error is PostgrestException &&
      const {'PGRST202', '42883'}.contains(error.code);

  Future<CommunityNotificationCommentPage> loadPage(
    String postId, {
    DateTime? after,
    String? afterId,
    int limit = 30,
  }) async {
    try {
      final threads = await repository.loadPostCommentThreads(
        postId,
        after: after,
        afterId: afterId,
        limit: limit,
      );
      CommunityOwnerOperation.checkCurrent();
      return CommunityNotificationCommentPage(
        comments: [
          for (final thread in threads) ...[thread.root, ...thread.replies],
        ],
        hasMore: threads.length == limit,
        after: threads.lastOrNull?.root.createdAt,
        afterId: threads.lastOrNull?.root.id,
      );
    } catch (error) {
      if (!_missingThreads(error)) rethrow;
      // Missing v3 preserves v2's real rows, cursor and unknown total counts.
      final rows = await repository.loadPostComments(
        postId,
        after: after,
        afterId: afterId,
        limit: limit,
      );
      CommunityOwnerOperation.checkCurrent();
      return CommunityNotificationCommentPage(
        comments: rows,
        hasMore: rows.length == limit,
        after: rows.lastOrNull?.createdAt,
        afterId: rows.lastOrNull?.id,
      );
    }
  }

  Future<CommunityNotificationCommentFocus?> loadFocus(
    String postId,
    String commentId, {
    bool Function()? isCurrent,
  }) async {
    void check() {
      if (isCurrent?.call() == false) {
        throw const CommunityOwnerOperationCancelled();
      }
      CommunityOwnerOperation.checkCurrent();
    }

    if (!CommunityDeepLink.isContentId(postId) ||
        !CommunityDeepLink.isContentId(commentId)) {
      throw ArgumentError('Invalid comment destination');
    }
    final roots = <String, CommunityComment>{};
    DateTime? after;
    String? afterId;
    CommunityComment? target;
    // Read actual authorized rows, including targets beyond the first page.
    // Keep cursor progress explicit; cancellation fences every network page.
    while (target == null) {
      check();
      final rows = await repository.loadPostComments(
        postId,
        after: after,
        afterId: afterId,
        limit: 100,
      );
      check();
      if (rows.isEmpty) return null;
      for (final row in rows) {
        if (row.parentId == null) roots[row.id] = row;
        if (row.id == commentId) target = row;
      }
      final last = rows.last;
      if (after != null &&
          (last.createdAt.isBefore(after) ||
              (last.createdAt == after && last.id.compareTo(afterId!) <= 0))) {
        throw const FormatException(
          'Community comment cursor did not progress',
        );
      }
      if (target != null) break;
      if (rows.length < 100) return null;
      after = last.createdAt;
      afterId = last.id;
    }
    final found = target;
    final root = found.parentId == null ? found : roots[found.parentId];
    if (root == null) return null; // Never invent a missing/removed parent.
    CommunityCommentThread thread = CommunityCommentThread(
      root: root,
      replies: found.parentId == null ? const [] : [found],
      replyCount: root.replyCount,
    );
    final before = _before(root);
    try {
      var rootCursor = before;
      CommunityCommentThread? fresh;
      while (fresh == null) {
        check();
        final threads = await repository.loadPostCommentThreads(
          postId,
          after: rootCursor.$1,
          afterId: rootCursor.$2,
          limit: 50,
        );
        check();
        fresh = threads.where((item) => item.root.id == root.id).firstOrNull;
        if (fresh != null) break;
        if (threads.isEmpty || threads.length < 50) return null;
        final last = threads.last.root;
        if (!_progresses(last, rootCursor)) {
          throw const FormatException(
            'Community thread cursor did not progress',
          );
        }
        if (_past(last, root)) return null;
        rootCursor = (last.createdAt, last.id);
      }
      thread = fresh;
      if (found.parentId != null &&
          !thread.replies.any((row) => row.id == found.id)) {
        final cursor = _before(found);
        var replyCursor = cursor;
        CommunityComment? reply;
        while (reply == null) {
          check();
          final replies = await repository.loadCommentReplies(
            root.id,
            after: replyCursor.$1,
            afterId: replyCursor.$2,
            limit: 50,
          );
          check();
          reply = replies.where((row) => row.id == found.id).firstOrNull;
          if (reply != null) break;
          if (replies.isEmpty || replies.length < 50) return null;
          final last = replies.last;
          if (!_progresses(last, replyCursor)) {
            throw const FormatException(
              'Community reply cursor did not progress',
            );
          }
          if (_past(last, found)) return null;
          replyCursor = (last.createdAt, last.id);
        }
        thread = thread.copyWith(replies: [...thread.replies, reply]);
      }
    } catch (error) {
      if (!_missingThreads(error)) rethrow;
      check();
      final currentRoot = await _readVisibleComment(
        postId,
        root,
        before,
        check,
      );
      if (currentRoot == null || currentRoot.parentId != null) return null;
      final replies = <CommunityComment>[];
      if (found.parentId != null) {
        final cursor = _before(found);
        final reply = await _readVisibleComment(postId, found, cursor, check);
        if (reply == null || reply.parentId != root.id) return null;
        replies.add(reply);
      }
      thread = CommunityCommentThread(
        root: currentRoot,
        replies: replies,
        replyCount: currentRoot.replyCount,
      );
    }
    return CommunityNotificationCommentFocus(
      thread: thread,
      commentId: found.id,
    );
  }

  Future<CommunityComment?> _readVisibleComment(
    String postId,
    CommunityComment target,
    (DateTime, String) initial,
    void Function() check,
  ) async {
    var cursor = initial;
    while (true) {
      check();
      final rows = await repository.loadPostComments(
        postId,
        after: cursor.$1,
        afterId: cursor.$2,
        limit: 100,
      );
      check();
      final found = rows.where((row) => row.id == target.id).firstOrNull;
      if (found != null) return found;
      if (rows.isEmpty || rows.length < 100) return null;
      final last = rows.last;
      if (!_progresses(last, cursor)) {
        throw const FormatException(
          'Community comment cursor did not progress',
        );
      }
      if (_past(last, target)) return null;
      cursor = (last.createdAt, last.id);
    }
  }

  bool _progresses(CommunityComment row, (DateTime, String) cursor) =>
      row.createdAt.isAfter(cursor.$1) ||
      (row.createdAt == cursor.$1 && row.id.compareTo(cursor.$2) > 0);
  bool _past(CommunityComment row, CommunityComment target) =>
      row.createdAt.isAfter(target.createdAt) ||
      (row.createdAt == target.createdAt && row.id.compareTo(target.id) > 0);

  (DateTime, String) _before(CommunityComment row) {
    final number =
        BigInt.parse(row.id.replaceAll('-', ''), radix: 16) - BigInt.one;
    final hex = number.toRadixString(16).padLeft(32, '0');
    final previous =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    if (CommunityDeepLink.isContentId(previous)) {
      return (row.createdAt, previous);
    }
    // The rare UUID borrow across a version/variant boundary is handled by a
    // preceding timestamp, never an invalid UUID passed to the old RPC.
    return (
      row.createdAt.subtract(const Duration(microseconds: 1)),
      '00000000-0000-4000-8000-000000000000',
    );
  }
}
