part of 'community_post_moderation_page.dart';

extension _CommunityModerationQueueTabs on _CommunityPostModerationPageState {
  Widget _aiCoachReportsTab(_CommunityModerationQueue queue) =>
      RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AiCoachSafetyReportQueueSection(
              reports: queue.aiCoachReports,
              reviewUnavailable: queue.aiCoachReportReviewUnavailable,
              busyReportIds: _busyTargets
                  .where((target) => target.startsWith('ai-coach:'))
                  .map((target) => target.substring('ai-coach:'.length))
                  .toSet(),
              onReview: _reviewAiCoachSafetyReport,
            ),
          ],
        ),
      );

  Widget _communityReportsTab(_CommunityModerationQueue queue) {
    if (!queue.reviewUnavailable &&
        queue.posts.isEmpty &&
        queue.hiddenPosts.isEmpty &&
        queue.reports.isEmpty &&
        queue.commentReports.isEmpty &&
        !queue.commentReviewUnavailable &&
        queue.rewards.isEmpty) {
      return Center(
        child: Text(
          communityText(
            context,
            'The moderation queue is clear.',
            'قائمة مراجعة المجتمع خالية.',
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (queue.reviewUnavailable) const _ReviewVersionUnavailable(),
          Text(
            communityText(
              context,
              'Posts awaiting human review',
              'منشورات بانتظار المراجعة البشرية',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (queue.reviewUnavailable)
            const SizedBox.shrink()
          else if (queue.posts.isEmpty)
            Text(
              communityText(
                context,
                'No pending posts.',
                'لا توجد منشورات معلّقة.',
              ),
            )
          else
            for (final post in queue.posts) ...[
              _PendingPostCard(
                post: post,
                busy: _busyTargets.contains(post.id),
                onApprove: () =>
                    _decidePost(post, CommunityPostModerationDecision.approved),
                onReject: () =>
                    _decidePost(post, CommunityPostModerationDecision.rejected),
                onPublishOnly: _reviewedPosts[post.id]?.canPublishOnly == true
                    ? () => _decidePost(
                        post,
                        CommunityPostModerationDecision.approved,
                        publishOnly: true,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 14),
          if (queue.rewards.isNotEmpty) ...[
            Text(
              communityText(
                context,
                'Publication and reward are separate',
                'النشر والمكافأة عمليتان منفصلتان',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final review in queue.rewards)
              _RewardReviewCard(
                review: review,
                busy: _busyTargets.contains(review.snapshot.post.id),
                onRequest: () => _rewardAction(review, null),
                onApprove: () => _rewardAction(review, true),
                onReject: () => _rewardAction(review, false),
              ),
            const SizedBox(height: 14),
          ],
          Text(
            communityText(context, 'Hidden posts', 'المنشورات المخفية'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (queue.hiddenPosts.isEmpty)
            Text(
              communityText(
                context,
                'No hidden posts.',
                'لا توجد منشورات مخفية.',
              ),
            )
          else
            for (final post in queue.hiddenPosts) ...[
              _HiddenPostCard(
                post: post,
                busy: _busyTargets.contains(post.id),
                onRestore: () => _restorePost(post),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 14),
          Text(
            communityText(context, 'Open reports', 'البلاغات المفتوحة'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (queue.reports.isEmpty)
            Text(
              communityText(
                context,
                'No open reports.',
                'لا توجد بلاغات مفتوحة.',
              ),
            )
          else
            for (final report in queue.reports) ...[
              _OpenReportCard(
                report: report,
                busy: _busyTargets.contains('community:${report['id']}'),
                onReview: () => _reviewReport(report),
              ),
              const SizedBox(height: 12),
            ],
          if (queue.commentReviewUnavailable)
            Text(
              communityText(
                context,
                'Comment report review is unavailable on this server.',
                'مراجعة بلاغات التعليقات غير متاحة على هذا الخادم.',
              ),
            ),
          for (final report in queue.commentReports)
            _CommentReportCard(
              report: report,
              busy: _busyTargets.contains('comment:${report.id}'),
              onReview: () =>
                  _reviewReport(report.reviewRequest, source: 'comment'),
            ),
        ],
      ),
    );
  }
}
