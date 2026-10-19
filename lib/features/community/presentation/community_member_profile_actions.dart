part of 'community_hub_page.dart';

extension _CommunityMemberProfileActions on _CommunityMemberProfilePageState {
  Future<void> _manageMemberSafety(String action) async {
    final visit = _captureProfileVisit();
    final profile = _profile;
    if (visit == null ||
        profile == null ||
        profile.isSelf ||
        (_relationshipBusy || _memberSafetyBusy) ||
        !const {'report', 'block'}.contains(action)) {
      return;
    }
    _setProfileState(() => _memberSafetyBusy = true);
    try {
      await visit.run(() async {
        if (action == 'report') {
          final draft = await showCommunityReportSheet(
            context,
            target: CommunityReportTarget.profile,
            guard: visit.guard,
          );
          visit.check();
          if (draft == null) return;
          await visit.repository.report(
            targetKind: 'profile',
            targetId: profile.userId,
            reason: draft.reason,
          );
          visit.check();
          if (mounted) {
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
        } else {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => visit.guard(
              BilPearlMaterialAlertDialog(
                title: Text(
                  communityText(
                    context,
                    'Block this member?',
                    'حظر هذا العضو؟',
                  ),
                ),
                content: Text(
                  communityText(
                    context,
                    'You will no longer see each other in Community or messages.',
                    'لن يتمكن أي منكما من رؤية الآخر في المجتمع أو الرسائل.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(communityText(context, 'Cancel', 'إلغاء')),
                  ),
                  FilledButton(
                    key: const Key('community-member-confirm-block'),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(communityText(context, 'Block', 'حظر')),
                  ),
                ],
              ),
            ),
          );
          visit.check();
          if (confirmed != true) return;
          await visit.repository.blockMember(profile.userId);
          visit.check();
          if (mounted) {
            _setProfileState(() => _profile = null);
            await Navigator.of(context).maybePop();
          }
        }
      });
    } on CommunityOwnerOperationCancelled {
      // The original profile visit alone owns the action.
    } catch (_) {
      if (visit.isCurrent()) _showFailure();
    } finally {
      if (visit.isCurrent()) _setProfileState(() => _memberSafetyBusy = false);
    }
  }

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
    await showBilPearlBottomSheet<void>(
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
    if (!const {'report', 'delete', 'block'}.contains(action)) return;
    final visit = _captureProfileVisit();
    if (visit == null || _managingPost) return;
    final repository = visit.repository;
    try {
      await visit.run(() async {
        if (!mounted || !visit.isCurrent()) return;
        CommunityReportDraft? reportDraft;
        if (action == 'report') {
          reportDraft = await showCommunityReportSheet(
            context,
            target: CommunityReportTarget.post,
            guard: visit.guard,
          );
          visit.check();
          if (reportDraft == null || !mounted) return;
        }
        if (action == 'delete' || action == 'block') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => visit.guard(
              BilPearlMaterialAlertDialog(
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
              reason: reportDraft!.reason,
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
    await showBilPearlBottomSheet<void>(
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
