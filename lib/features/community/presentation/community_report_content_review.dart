part of 'community_post_moderation_page.dart';

class _PendingReportDecision {
  const _PendingReportDecision(this.review, this.remove, this.operationId);
  final CommunityReportReview review;
  final bool remove;
  final String operationId;
}

extension _ReportContentReviewActions on _CommunityPostModerationPageState {
  Future<void> _reviewReport(
    Map<String, dynamic> report, {
    String source = 'community',
  }) async {
    final id = report['id'], target = report['target_id'];
    final repository = _repository, visit = _visit;
    final key = '$source:$id';
    if (id is! String ||
        target is! String ||
        repository == null ||
        visit == null ||
        !visit.isCurrent ||
        _busyTargets.contains(key) ||
        !_decisionEditors.add(key)) {
      return;
    }
    try {
      await visit.requireFreshModerator();
      var pending = _pendingReportDecisions[key];
      if (pending == null) {
        final review = await visit.run(
          () => repository.loadReportedContent(
            reportId: id,
            source: source,
            targetId: target,
          ),
        );
        if (!mounted || !visit.isCurrent) return;
        final remove = await showDialog<bool>(
          context: context,
          builder: (_) => _ReportedContentDialog(review: review, visit: visit),
        );
        if (remove == null || !mounted || !visit.isCurrent) return;
        final operationId = _decisionIds.putIfAbsent(
          'report:$source:$id:${review.revision}:$remove',
          () => const Uuid().v4(),
        );
        pending = _PendingReportDecision(review, remove, operationId);
        _pendingReportDecisions[key] = pending;
      }
      // A timeout/readback failure retries the previously confirmed operation,
      // not a new decision against content that may already have been removed.
      _updateReportDecisionUi(() => _busyTargets.add(key));
      await visit.requireFreshModerator();
      final confirmed = pending;
      await visit.run(
        () => repository.decideReportedContent(
          review: confirmed.review,
          remove: confirmed.remove,
          operationId: confirmed.operationId,
        ),
      );
      await _reloadAndReadback(visit);
      if (!mounted || !visit.isCurrent) return;
      _pendingReportDecisions.remove(key);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Report decision saved.',
              'تم حفظ قرار البلاغ.',
            ),
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted || !visit.isCurrent) return;
      final changed =
          error is PostgrestException &&
          error.code == '40001' &&
          error.message == 'community_report_content_changed';
      if (changed) {
        // A proven stale snapshot was rejected before any decision committed.
        // Reopen the content editor; uncertain transport/readback failures keep
        // their original operation ID for reconciliation instead.
        _pendingReportDecisions.remove(key);
      }
      final unavailable =
          error is PostgrestException &&
          const {'PGRST202', '42883'}.contains(error.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              changed
                  ? 'The reported content changed. Review it again before deciding.'
                  : unavailable
                  ? 'Reported content review is unavailable on this server. No decision was submitted.'
                  : 'Could not confirm the report decision. Refresh and retry.',
              changed
                  ? 'تغيّر المحتوى المُبلّغ عنه. راجعه مجددًا قبل اتخاذ القرار.'
                  : unavailable
                  ? 'مراجعة المحتوى المُبلّغ غير متاحة على هذا الخادم. لم يُرسل قرار.'
                  : 'تعذر تأكيد قرار البلاغ. حدّث ثم أعد المحاولة.',
            ),
          ),
        ),
      );
    } finally {
      _decisionEditors.remove(key);
      if (mounted && visit.isCurrent) {
        _updateReportDecisionUi(() => _busyTargets.remove(key));
      }
    }
  }
}

class _CommentReportCard extends StatelessWidget {
  const _CommentReportCard({
    required this.report,
    required this.busy,
    required this.onReview,
  });
  final CommunityCommentReport report;
  final bool busy;
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) => BilPearlMaterialCard(
    key: Key('community-comment-report-${report.id}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            communityText(
              context,
              'Reported comment or reply',
              'تعليق أو رد مُبلّغ عنه',
            ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(report.body, maxLines: 4, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(report.reason),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: busy ? null : onReview,
            key: Key('community-comment-report-view-${report.id}'),
            child: Text(
              communityText(
                context,
                'Review reported content',
                'مراجعة المحتوى المُبلّغ عنه',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReportedContentDialog extends StatefulWidget {
  const _ReportedContentDialog({required this.review, required this.visit});
  final CommunityReportReview review;
  final CommunityModerationVisit visit;
  @override
  State<_ReportedContentDialog> createState() => _ReportedContentDialogState();
}

class _ReportedContentDialogState extends State<_ReportedContentDialog> {
  final _decoded = <int, bool>{};
  StreamSubscription<AuthState>? _subscription;
  bool _retired = false;
  bool get _current => !_retired && widget.visit.isCurrent;
  bool get _imagesReady =>
      widget.review.post?.mediaItems.asMap().keys.every(
        (index) => _decoded[index] == true,
      ) ??
      true;
  @override
  void initState() {
    super.initState();
    _subscription = widget
        .visit
        .repository
        .communitySocialClient
        .auth
        .onAuthStateChange
        .listen((_) {
          if (!widget.visit.isCurrent && mounted) {
            setState(() => _retired = true);
          }
        });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _markDecoded(int index, bool ready) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _current && _decoded[index] != ready) {
          setState(() => _decoded[index] = ready);
        }
      });
  @override
  Widget build(BuildContext context) {
    final review = widget.review, post = widget.review.post;
    return BilPearlMaterialAlertDialog(
      key: const Key('community-report-content-review'),
      title: Text(
        communityText(
          context,
          'Review reported content',
          'مراجعة المحتوى المُبلّغ عنه',
        ),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_current)
                Text(
                  communityText(
                    context,
                    'Sign-in required',
                    'يلزم تسجيل الدخول',
                  ),
                )
              else ...[
                Text(review.reason),
                const Divider(),
                if (!review.available)
                  Text(
                    communityText(
                      context,
                      'This content is no longer available. You can close the report.',
                      'هذا المحتوى لم يعد متاحًا. يمكنك إغلاق البلاغ.',
                    ),
                  )
                else
                  SelectableText(
                    review.body!,
                    key: const Key('community-reported-content-body'),
                  ),
                if (review.parentBody != null) ...[
                  const Divider(),
                  Text(communityText(context, 'Reply context', 'سياق الرد')),
                  SelectableText(review.parentBody!),
                ],
                if (post != null && post.mediaItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ModerationMediaGrid(post: post, onDecoded: _markDecoded),
                ],
                if (post?.poll != null) ...[
                  const SizedBox(height: 12),
                  _ModerationPollPreview(postId: post!.id, poll: post.poll!),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(communityText(context, 'Cancel', 'إلغاء')),
        ),
        if (_current)
          FilledButton.tonal(
            key: const Key('community-report-close-confirm'),
            onPressed: _imagesReady
                ? () => Navigator.pop(context, false)
                : null,
            child: Text(communityText(context, 'Close report', 'إغلاق البلاغ')),
          ),
        if (_current && review.canRemove)
          FilledButton(
            key: const Key('community-report-remove-confirm'),
            onPressed: _imagesReady ? () => Navigator.pop(context, true) : null,
            child: Text(
              communityText(
                context,
                'Remove reported content',
                'إزالة المحتوى المُبلّغ عنه',
              ),
            ),
          ),
      ],
    );
  }
}
