part of 'community_hub_page.dart';

extension _CommunityMemberProfileActions on _CommunityMemberProfilePageState {
  Future<void> _requestFriend() async {
    final visit = _captureProfileVisit();
    final repository = visit?.repository;
    final profile = _profile;
    if (repository == null ||
        profile == null ||
        profile.isSelf ||
        _relationshipBusy) {
      return;
    }
    _setProfileState(() => _relationshipBusy = true);
    try {
      await visit!.run(() async {
        await repository.requestFriend(profile.userId);
        visit.check();
        final refreshed = await repository.loadProfileOverview(profile.userId);
        visit.check();
        _setProfileState(() => _profile = refreshed);
      });
    } on CommunityOwnerOperationCancelled {
      // A completed old mutation must not start follow-up reads as a new owner.
    } catch (_) {
      if (visit?.isCurrent() == true) _showFailure();
    } finally {
      if (visit?.isCurrent() == true) {
        _setProfileState(() => _relationshipBusy = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    final visit = _captureProfileVisit();
    final repository = visit?.repository;
    final profile = _profile;
    if (repository == null ||
        profile == null ||
        profile.isSelf ||
        _followBusy ||
        (!profile.viewerFollows && !profile.allowFollows)) {
      return;
    }
    _setProfileState(() => _followBusy = true);
    try {
      await visit!.run(() async {
        if (profile.viewerFollows) {
          await repository.unfollow(profile.userId);
        } else {
          await repository.follow(profile.userId);
        }
        visit.check();
        final values = await Future.wait<Object>([
          repository.loadProfileOverview(profile.userId),
          repository.loadCommunityCreatorProfile(profile.userId),
        ]);
        visit.check();
        _setProfileState(() {
          _profile = values[0] as CommunityProfileOverview;
          _creator = values[1] as CommunityCreatorProfile;
        });
      });
    } on CommunityOwnerOperationCancelled {
      // A completed old mutation must not start follow-up reads as a new owner.
    } catch (_) {
      if (visit?.isCurrent() == true) _showFailure();
    } finally {
      if (visit?.isCurrent() == true) {
        _setProfileState(() => _followBusy = false);
      }
    }
  }

  Future<void> _openConnections(CommunityProfileConnectionKind kind) async {
    final visit = _captureProfileVisit();
    final profile = _profile;
    if (visit == null || profile == null) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => visit.guard(
        _CommunityProfileConnectionsSheet(
          visit: visit,
          profile: profile,
          kind: kind,
        ),
      ),
    );
  }

  Future<void> _managePost(CommunityPost post, String action) async {
    final visit = _captureProfileVisit();
    if (visit == null || _managingPost) return;
    final repository = visit.repository;
    try {
      await visit.run(() async {
        String? moderationReason;
        if (action == 'moderate_remove' || action == 'moderate_hide') {
          moderationReason = await showDialog<String>(
            context: context,
            builder: (dialogContext) => visit.guard(
              SimpleDialog(
                title: Text(
                  action == 'moderate_hide'
                      ? communityText(context, 'Hide post', 'إخفاء المنشور')
                      : communityText(context, 'Remove post', 'إزالة المنشور'),
                ),
                children: [
                  for (final reason in const [
                    'spam',
                    'abuse',
                    'misleading',
                    'privacy',
                    'unsafe_or_inappropriate',
                    'other',
                  ])
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialogContext, reason),
                      child: Text(reason),
                    ),
                ],
              ),
            ),
          );
          visit.check();
          if (moderationReason == null) return;
        }

        if (!mounted || !visit.isCurrent()) return;
        if (action == 'delete' || action == 'block') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => visit.guard(
              AlertDialog(
                title: Text(
                  action == 'delete'
                      ? communityText(context, 'Delete post?', 'حذف المشاركة؟')
                      : communityText(
                          context,
                          'Block this member?',
                          'حظر هذا العضو؟',
                        ),
                ),
                content: Text(
                  action == 'delete'
                      ? communityText(
                          context,
                          'This removes your post from Community.',
                          'سيؤدي ذلك إلى إزالة مشاركتك من المجتمع.',
                        )
                      : communityText(
                          context,
                          'You will no longer see each other in Community or messages.',
                          'لن يتمكن أي منكما من رؤية الآخر في المجتمع أو الرسائل.',
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(communityText(context, 'Cancel', 'إلغاء')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(
                      action == 'delete'
                          ? communityText(context, 'Delete', 'حذف')
                          : communityText(context, 'Block', 'حظر'),
                    ),
                  ),
                ],
              ),
            ),
          );
          visit.check();
          if (confirmed != true) return;
        }

        visit.check();
        _setProfileState(() => _managingPost = true);
        try {
          if (action == 'report') {
            await repository.report(
              targetKind: 'post',
              targetId: post.id,
              reason: 'user_reported_from_profile',
            );
            visit.check();
          } else if (action == 'delete') {
            await repository.deletePost(post.id);
            visit.check();
            if (visit.isCurrent()) {
              _setProfileState(
                () => _posts.removeWhere((item) => item.id == post.id),
              );
            }
          } else if (action == 'block') {
            await repository.blockMember(post.authorId);
            visit.check();
            if (mounted && visit.isCurrent()) context.pop();
          } else if (action == 'moderate_remove') {
            await repository.removePublishedPostAsModerator(
              postId: post.id,
              reason: moderationReason!,
            );
            visit.check();
            if (visit.isCurrent()) {
              _setProfileState(
                () => _posts.removeWhere((item) => item.id == post.id),
              );
            }
          } else if (action == 'moderate_hide') {
            await repository.hidePublishedPostAsModerator(
              postId: post.id,
              reason: moderationReason!,
            );
            visit.check();
            if (visit.isCurrent()) {
              _setProfileState(
                () => _posts.removeWhere((item) => item.id == post.id),
              );
            }
          }
          if (mounted && visit.isCurrent() && action == 'report') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  communityText(
                    context,
                    'Report sent for review.',
                    'تم إرسال البلاغ للمراجعة.',
                  ),
                ),
              ),
            );
          }
        } finally {
          if (visit.isCurrent()) _setProfileState(() => _managingPost = false);
        }
      });
    } on CommunityOwnerOperationCancelled {
      // A dialog belongs to the exact visit that opened it.
    } catch (_) {
      if (visit.isCurrent()) _showFailure();
    }
  }

  Future<void> _openSelfCreatorStats() async {
    final visit = _captureProfileVisit();
    final creator = _creator;
    if (visit == null || creator == null) return;
    final balance = _goldBalance;
    final quests = _quests;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => visit.guard(
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: _CommunityCreatorPanel(
            visit: visit,
            creator: creator,
            isSelf: true,
            goldBalance: balance,
            quests: quests,
          ),
        ),
      ),
    );
  }
}
