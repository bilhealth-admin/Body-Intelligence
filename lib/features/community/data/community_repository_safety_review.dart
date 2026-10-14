part of 'community_repository.dart';

class CommunityCommentReport {
  const CommunityCommentReport({
    required this.id,
    required this.commentId,
    required this.body,
    required this.reason,
    required this.createdAt,
  });
  final String id, commentId, body, reason;
  final DateTime createdAt;
  factory CommunityCommentReport.fromJson(Map<String, dynamic> row) {
    final id = row['report_id'], target = row['comment_id'];
    final body = row['body'], reason = row['reason'];
    final createdAt = DateTime.tryParse('${row['created_at']}');
    if (id is! String ||
        !CommunityRepository._uuid.hasMatch(id) ||
        target is! String ||
        !CommunityRepository._uuid.hasMatch(target) ||
        body is! String ||
        reason is! String ||
        reason.trim().isEmpty ||
        createdAt == null) {
      throw const FormatException('Invalid comment report');
    }
    return CommunityCommentReport(
      id: id,
      commentId: target,
      body: body,
      reason: reason,
      createdAt: createdAt,
    );
  }
  Map<String, dynamic> get reviewRequest => {
    'id': id,
    'target_id': commentId,
    'target_kind': 'comment',
    'reason': reason,
  };
}

class CommunityReportReview {
  const CommunityReportReview({
    required this.reportId,
    required this.source,
    required this.targetId,
    required this.targetKind,
    required this.revision,
    required this.reason,
    required this.available,
    required this.canRemove,
    this.body,
    this.parentBody,
    this.post,
  });
  final String reportId, source, targetId, targetKind, revision, reason;
  final bool available, canRemove;
  final String? body, parentBody;
  final CommunityPost? post;
  factory CommunityReportReview.fromJson(
    Object? raw, {
    required String reportId,
    required String source,
    required String targetId,
  }) {
    if (raw is! Map ||
        raw['contract_version'] != 1 ||
        raw['report_id'] != reportId ||
        raw['source'] != source ||
        raw['target_id'] != targetId ||
        raw['reason'] is! String ||
        !const {'open', 'reviewing'}.contains(raw['status']) ||
        raw['available'] is! bool ||
        raw['can_remove'] is! bool ||
        raw['revision'] is! String ||
        !CommunityReviewSnapshot.revisionPattern.hasMatch(
          raw['revision'] as String,
        ) ||
        !const {
          'post',
          'message',
          'food',
          'profile',
          'comment',
          'reply',
        }.contains(raw['target_kind']) ||
        (source == 'comment' &&
            !const {'comment', 'reply'}.contains(raw['target_kind'])) ||
        (raw['body'] != null && raw['body'] is! String) ||
        (raw['parent_body'] != null && raw['parent_body'] is! String) ||
        (raw['available'] == true && raw['body'] is! String) ||
        (raw['can_remove'] == true &&
            (raw['available'] != true ||
                !const {
                  'post',
                  'message',
                  'comment',
                  'reply',
                }.contains(raw['target_kind'])))) {
      throw const FormatException('Invalid reported content review');
    }
    final post = raw['post'] == null
        ? null
        : CommunityPost.fromJson(Map<String, dynamic>.from(raw['post'] as Map));
    if (post != null &&
        (raw['target_kind'] != 'post' ||
            post.id != targetId ||
            post.body != raw['body'])) {
      throw const FormatException('Invalid reported post');
    }
    return CommunityReportReview(
      reportId: reportId,
      source: source,
      targetId: targetId,
      targetKind: raw['target_kind'] as String,
      revision: raw['revision'] as String,
      reason: raw['reason'] as String,
      available: raw['available'] as bool,
      canRemove: raw['can_remove'] as bool,
      body: raw['body'] as String?,
      parentBody: raw['parent_body'] as String?,
      post: post,
    );
  }
  CommunityReportReview withPost(CommunityPost value) => CommunityReportReview(
    reportId: reportId,
    source: source,
    targetId: targetId,
    targetKind: targetKind,
    revision: revision,
    reason: reason,
    available: available,
    canRemove: canRemove,
    body: body,
    parentBody: parentBody,
    post: value,
  );
}

class CommunityBlockedMember {
  const CommunityBlockedMember({
    required this.id,
    required this.createdAt,
    this.name,
  });
  final String id;
  final DateTime createdAt;
  final String? name;
  factory CommunityBlockedMember.fromJson(Map<String, dynamic> row) {
    final id = row['blocked_id'], name = row['display_name'];
    final time = DateTime.tryParse('${row['created_at']}');
    if (id is! String ||
        !CommunityRepository._uuid.hasMatch(id) ||
        time == null ||
        (name != null &&
            (name is! String || name.trim().isEmpty || name.length > 60))) {
      throw const FormatException('Invalid owned block');
    }
    return CommunityBlockedMember(
      id: id,
      createdAt: time,
      name: name as String?,
    );
  }
}

mixin _CommunitySafetyReviewRepositoryMixin {
  SupabaseClient get _client;
  Future<T> _runCommunityOwnerOperation<T>(
    Future<T> Function(CommunityOwnerOperation) action,
  );
  Future<List<CommunityPost>> hydrateModerationReviewContents(
    List<CommunityPost> posts,
  );

  Future<List<CommunityCommentReport>> loadOpenCommentReports() =>
      _runCommunityOwnerOperation((operation) async {
        final raw = await _client.rpc(
          'bil_social_comment_reports_v2',
          params: {'p_limit': 100},
        );
        operation.check();
        if (raw is! List) {
          throw const FormatException('Invalid comment reports');
        }
        final seen = <String>{};
        return List<CommunityCommentReport>.unmodifiable(
          raw.map((row) {
            if (row is! Map) {
              throw const FormatException('Invalid comment report');
            }
            final report = CommunityCommentReport.fromJson(
              Map<String, dynamic>.from(row),
            );
            if (!seen.add(report.id)) {
              throw const FormatException('Duplicate comment report');
            }
            return report;
          }),
        );
      });

  Future<CommunityReportReview> loadReportedContent({
    required String reportId,
    required String source,
    required String targetId,
  }) => _runCommunityOwnerOperation((operation) async {
    if (!CommunityRepository._uuid.hasMatch(reportId) ||
        !CommunityRepository._uuid.hasMatch(targetId) ||
        !const {'community', 'comment'}.contains(source)) {
      throw ArgumentError('Invalid report');
    }
    Future<CommunityReportReview> read() async {
      final raw = await _client.rpc(
        'bil_community_report_content_v1',
        params: {'p_report_id': reportId, 'p_source': source},
      );
      operation.check();
      return CommunityReportReview.fromJson(
        raw,
        reportId: reportId,
        source: source,
        targetId: targetId,
      );
    }

    final before = await read();
    if (before.post == null) return before;
    final posts = await hydrateModerationReviewContents([before.post!]);
    operation.check();
    final after = await read();
    if (before.revision != after.revision ||
        posts.length != 1 ||
        posts.single.id != targetId) {
      throw const StateErrorReviewChanged();
    }
    return before.withPost(posts.single);
  });

  Future<void> decideReportedContent({
    required CommunityReportReview review,
    required bool remove,
    required String operationId,
  }) => _runCommunityOwnerOperation((operation) async {
    if (!CommunityRepository._uuid.hasMatch(operationId) ||
        (remove && !review.canRemove)) {
      throw ArgumentError('Invalid report decision');
    }
    void validate(Object? raw) {
      if (raw is! Map ||
          raw['contract_version'] != 1 ||
          raw['report_id'] != review.reportId ||
          raw['source'] != review.source ||
          raw['target_id'] != review.targetId ||
          raw['reviewed_revision'] != review.revision ||
          raw['operation_id'] != operationId ||
          raw['status'] != 'closed' ||
          raw['receipt_state'] != 'executed' ||
          raw['content_removed'] != remove ||
          raw['duplicate'] is! bool) {
        throw const FormatException('Invalid report decision receipt');
      }
    }

    final raw = await _client.rpc(
      'bil_decide_community_report_v1',
      params: {
        'p_report_id': review.reportId,
        'p_source': review.source,
        'p_expected_revision': review.revision,
        'p_remove': remove,
        'p_operation_id': operationId,
      },
    );
    operation.check();
    validate(raw);
    final readback = await _client.rpc(
      'bil_get_community_report_decision_v1',
      params: {'p_operation_id': operationId},
    );
    operation.check();
    validate(readback);
  });

  Future<List<CommunityBlockedMember>>
  loadBlockedMembers() => _runCommunityOwnerOperation((operation) async {
    Object? raw;
    try {
      raw = await _client.rpc('bil_my_blocked_members_v1');
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
      // An old server can return only this owner's RLS-authorized block rows.
      // It supplies no display name; never query a blocked private profile.
      final rows = await _client
          .from('bil_blocks')
          .select('blocker_id,blocked_id,created_at')
          .eq('blocker_id', operation.ownerId!);
      raw = rows;
      if (rows.any((row) => row['blocker_id'] != operation.ownerId)) {
        throw const FormatException('Unexpected block owner');
      }
    }
    operation.check();
    if (raw is! List) throw const FormatException('Invalid block list');
    final seen = <String>{};
    return List<CommunityBlockedMember>.unmodifiable(
      raw.map((row) {
        if (row is! Map) throw const FormatException('Invalid block row');
        final member = CommunityBlockedMember.fromJson(
          Map<String, dynamic>.from(row),
        );
        if (!seen.add(member.id)) {
          throw const FormatException('Duplicate block');
        }
        return member;
      }),
    );
  });

  Future<void> unblockMember(String userId) => _runCommunityOwnerOperation((
    operation,
  ) async {
    if (!CommunityRepository._uuid.hasMatch(userId) ||
        userId == operation.ownerId) {
      throw ArgumentError('Invalid blocked member');
    }
    final owner = operation.ownerId!;
    await _client
        .from('bil_blocks')
        .delete()
        .eq('blocker_id', owner)
        .eq('blocked_id', userId);
    operation.check();
    final remaining = await _client
        .from('bil_blocks')
        .select('blocked_id')
        .eq('blocker_id', owner)
        .eq('blocked_id', userId);
    operation.check();
    if (remaining.isNotEmpty) throw StateError('Block removal not confirmed');
  });
}
