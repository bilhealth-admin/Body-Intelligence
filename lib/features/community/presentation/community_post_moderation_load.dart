part of 'community_post_moderation_page.dart';

extension _ModerationQueueLoading on _CommunityPostModerationPageState {
  Future<_CommunityModerationQueue> _load() async {
    final repository = _repository;
    final visit = _visit;
    if (repository == null || visit == null || !visit.isCurrent) {
      throw const AuthException('Sign-in required');
    }
    await visit.requireFreshModerator();
    return visit.run(() async {
      final values = await Future.wait<Object>([
        repository.loadPendingPostsForModeration(),
        repository.loadHiddenPostsForModeration(),
        repository.loadOpenModerationReports(),
      ]);
      if (!visit.isCurrent) {
        throw const AuthException('Moderator session changed');
      }
      final posts = values[0] as List<CommunityPost>;
      final hiddenPosts = values[1] as List<CommunityPost>;
      final reports = values[2] as List<Map<String, dynamic>>;
      var aiCoachReportReviewUnavailable = false;
      List<AiCoachSafetyReport> aiCoachReports;
      try {
        aiCoachReports = await repository.loadAiCoachSafetyReports();
      } on PostgrestException catch (error) {
        if (error.code != 'PGRST202' && error.code != '42883') rethrow;
        aiCoachReports = const [];
        aiCoachReportReviewUnavailable = true;
      }
      if (!visit.isCurrent) {
        throw const AuthException('Moderator session changed');
      }
      var commentReviewUnavailable = false;
      List<CommunityCommentReport> commentReports;
      try {
        commentReports = await repository.loadOpenCommentReports();
      } on PostgrestException catch (error) {
        if (error.code != 'PGRST202' && error.code != '42883') rethrow;
        commentReports = const [];
        commentReviewUnavailable = true;
      }
      var reviewUnavailable = false;
      List<CommunityReviewSnapshot> reviewed;
      List<CommunityRewardReview> rewards;
      try {
        reviewed = await repository.loadReviewedPosts(posts);
        rewards = await repository.loadRewardReviewQueue();
      } on PostgrestException catch (error) {
        if (error.code != 'PGRST202' && error.code != '42883') rethrow;
        // Never silently submit an unversioned decision to an older RPC.
        // Existing reports and hidden-post tools remain independently usable.
        reviewUnavailable = true;
        reviewed = const [];
        rewards = const [];
      }
      final reviewContent = await repository.hydrateModerationReviewContents(
        hiddenPosts,
      );
      if (!visit.isCurrent) {
        throw const AuthException('Moderator session changed');
      }
      final byId = {for (final post in reviewContent) post.id: post};
      _reviewedPosts
        ..clear()
        ..addAll({for (final row in reviewed) row.post.id: row});
      return _CommunityModerationQueue(
        posts: [
          for (final row in reviewed)
            if (row.post.moderationStatus ==
                CommunityPostModerationStatus.pending)
              row.post,
        ],
        hiddenPosts: [for (final post in hiddenPosts) byId[post.id] ?? post],
        reports: reports,
        commentReports: commentReports,
        commentReviewUnavailable: commentReviewUnavailable,
        aiCoachReports: aiCoachReports,
        aiCoachReportReviewUnavailable: aiCoachReportReviewUnavailable,
        rewards: rewards,
        reviewUnavailable: reviewUnavailable,
      );
    });
  }
}
