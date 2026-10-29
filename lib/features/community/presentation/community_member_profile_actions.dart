part of 'community_hub_page.dart';

extension _CommunityMemberProfileActions on _CommunityMemberProfilePageState {
  Future<void> _manageMemberSafety(String action) async {
    final visit = _captureProfileVisit();
    final profile = _profile;
    if (visit == null ||
        profile == null ||
        profile.isSelf ||
        (_relationshipBusy || _memberSafetyBusy || _followBusy) ||
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
          if (draft == null || !mounted) return;
          final created = await submitCommunityReportWithReceipt(
            context: context,
            checkOwner: visit.check,
            send: () => visit.repository.report(
              targetKind: 'profile',
              targetId: profile.userId,
              reason: draft.reason,
            ),
          );
          visit.check();
          if (mounted && created) {
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
        _relationshipBusy ||
        _followBusy ||
        _memberSafetyBusy ||
        (profile.relationship == CommunityRelationshipStatus.none &&
            !profile.allowFriendRequests)) {
      return;
    }
    _setProfileState(() => _relationshipBusy = true);
    try {
      await visit!.run(() async {
        final relationship = profile.relationship;
        if (relationship == CommunityRelationshipStatus.none) {
          await repository.requestFriend(profile.userId);
        } else if (const {
          CommunityRelationshipStatus.pending,
          CommunityRelationshipStatus.incoming,
          CommunityRelationshipStatus.accepted,
        }.contains(relationship)) {
          bool? response;
          if (relationship != CommunityRelationshipStatus.pending) {
            response = await _reviewProfileFriendship(visit, profile);
            visit.check();
            if (response == null) return;
          }
          // The profile projection has no friendship ID. Resolve exactly the
          // viewer/target row before issuing an ID-based mutation.
          final rows = await repository.loadFriendshipsWithProfiles();
          visit.check();
          final matches = rows
              .where((row) {
                final outgoing =
                    row['requester_id'] == visit.ownerId &&
                    row['addressee_id'] == profile.userId;
                final incoming =
                    row['requester_id'] == profile.userId &&
                    row['addressee_id'] == visit.ownerId;
                return row['other_user_id'] == profile.userId &&
                    row['id'] is String &&
                    (row['id'] as String).isNotEmpty &&
                    switch (relationship) {
                      CommunityRelationshipStatus.pending =>
                        outgoing && row['status'] == 'pending',
                      CommunityRelationshipStatus.incoming =>
                        incoming && row['status'] == 'pending',
                      CommunityRelationshipStatus.accepted =>
                        (outgoing || incoming) && row['status'] == 'accepted',
                      _ => false,
                    };
              })
              .toList(growable: false);
          if (matches.length != 1) {
            throw StateError('Friendship is no longer available');
          }
          final id = matches.single['id'] as String;
          switch (relationship) {
            case CommunityRelationshipStatus.pending:
              await repository.cancelFriendRequest(id);
            case CommunityRelationshipStatus.incoming:
              await repository.respondToFriendship(id, accept: response!);
            case CommunityRelationshipStatus.accepted:
              await repository.removeFriendship(id);
            default:
              return;
          }
        } else {
          return;
        }
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

  Future<bool?> _reviewProfileFriendship(
    _CommunityProfileVisit visit,
    CommunityProfileOverview profile,
  ) {
    final incoming =
        profile.relationship == CommunityRelationshipStatus.incoming;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => visit.guard(
        BilPearlMaterialAlertDialog(
          title: Text(
            incoming
                ? communityText(context, 'Review request', 'مراجعة الطلب')
                : communityText(context, 'Remove friend?', 'إزالة الصديق؟'),
          ),
          content: Text(profile.displayName),
          actions: [
            TextButton(
              key: const Key('community-profile-relationship-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(communityText(context, 'Cancel', 'إلغاء')),
            ),
            if (incoming)
              TextButton(
                key: const Key('community-profile-reject-request'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(communityText(context, 'Decline', 'رفض')),
              ),
            FilledButton(
              key: Key(
                incoming
                    ? 'community-profile-accept-request'
                    : 'community-profile-remove-friend',
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                incoming
                    ? communityText(context, 'Accept', 'قبول')
                    : communityText(context, 'Remove friend', 'إزالة الصديق'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final visit = _captureProfileVisit();
    final repository = visit?.repository;
    final profile = _profile;
    if (repository == null ||
        profile == null ||
        profile.isSelf ||
        _followBusy ||
        _relationshipBusy ||
        _memberSafetyBusy ||
        (!profile.viewerFollows && !profile.allowFollows)) {
      return;
    }
    final metadataGeneration = ++_followMetadataGeneration;
    CommunityProfileOverview? verifiedProfile;
    _setProfileState(() => _followBusy = true);
    try {
      await visit!.run(() async {
        if (profile.viewerFollows) {
          await repository.unfollow(profile.userId);
        } else {
          await repository.follow(profile.userId);
        }
        visit.check();
        final refreshed = await repository.loadProfileOverview(profile.userId);
        visit.check();
        _setProfileState(() => _profile = refreshed);
        verifiedProfile = refreshed;
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
    final verified = verifiedProfile;
    if (verified != null && visit?.isCurrent() == true) {
      unawaited(
        _refreshCreatorAfterFollow(visit!, verified, metadataGeneration),
      );
    }
  }

  Future<void> _refreshCreatorAfterFollow(
    _CommunityProfileVisit visit,
    CommunityProfileOverview verified,
    int generation,
  ) async {
    bool isCurrent() =>
        visit.isCurrent() &&
        generation == _followMetadataGeneration &&
        identical(_profile, verified);
    if (!isCurrent()) return;
    try {
      await visit.run(() async {
        if (!isCurrent()) return;
        final creator = await visit.repository.loadCommunityCreatorProfile(
          verified.userId,
        );
        visit.check();
        if (!isCurrent()) return;
        _setProfileState(() => _creator = creator);
      });
    } on CommunityOwnerOperationCancelled {
      // Metadata belongs only to the verified relationship's original visit.
    } on Object {
      // Optional metadata never holds the verified relationship button busy.
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
    if (!visit.isCurrent()) return;
    try {
      await visit.run(() async {
        final refreshed = await visit.repository.loadProfileOverview(
          profile.userId,
        );
        visit.check();
        _setProfileState(() => _profile = refreshed);
      });
    } on CommunityOwnerOperationCancelled {
      // The closed sheet cannot refresh a later owner's profile.
    } on Object {
      if (visit.isCurrent()) _showFailure();
    }
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
          var reportCreated = false;
          if (action == 'report') {
            if (!mounted) return;
            reportCreated = await submitCommunityReportWithReceipt(
              context: context,
              checkOwner: visit.check,
              send: () => repository.report(
                targetKind: 'post',
                targetId: post.id,
                reason: reportDraft!.reason,
              ),
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
          if (mounted &&
              visit.isCurrent() &&
              action == 'report' &&
              reportCreated) {
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
