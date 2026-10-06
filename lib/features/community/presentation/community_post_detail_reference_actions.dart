part of 'community_hub_page.dart';

extension _CommunityPostDetailReferenceActions
    on _CommunityPostDetailPageState {
  Future<void> _managePostAction(String action) => _runDetailOwner(() async {
    if (_managingPost) return;

    if (action == 'delete' || action == 'block') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => _detailOwnerScope.guard(
          AlertDialog(
            title: Text(
              action == 'delete'
                  ? communityText(context, 'Delete post?', 'حذف المنشور؟')
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
                      'سيؤدي ذلك إلى إزالة منشورك من المجتمع.',
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
      if (confirmed != true || !mounted || !_detailOwnerIsCurrent) return;
    }

    _setDetailState(() => _managingPost = true);
    try {
      if (action == 'delete') {
        await widget.repository.deletePost(widget.post.id);
        _detailOwnerScope.check();
        if (mounted && _detailOwnerIsCurrent) Navigator.of(context).pop();
        return;
      }
      if (action == 'block') {
        await widget.repository.blockMember(widget.post.authorId);
        _detailOwnerScope.check();
        if (mounted && _detailOwnerIsCurrent) Navigator.of(context).pop();
        return;
      }
      if (action == 'report') {
        await widget.repository.report(
          targetKind: 'post',
          targetId: widget.post.id,
          reason: 'user_reported_from_post_detail',
        );
        _detailOwnerScope.check();
        if (mounted && _detailOwnerIsCurrent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                communityText(
                  context,
                  'Report sent for human review.',
                  'تم إرسال البلاغ للمراجعة البشرية.',
                ),
              ),
            ),
          );
        }
      }
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } catch (_) {
      if (mounted && _detailOwnerIsCurrent) _showActionError();
    } finally {
      if (mounted && _detailOwnerIsCurrent) {
        _setDetailState(() => _managingPost = false);
      }
    }
  });

  Future<void> _togglePostSaved() => _runDetailOwner(() async {
    if (_savingPost) return;
    _setDetailState(() => _savingPost = true);
    try {
      final state = await widget.repository.setPostSaved(
        widget.post.id,
        saved: !_savedPost,
      );
      _detailOwnerScope.check();
      if (mounted && _detailOwnerIsCurrent) {
        _setDetailState(() => _savedPost = state.saved);
      }
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } catch (_) {
      if (mounted && _detailOwnerIsCurrent) _showActionError();
    } finally {
      if (mounted && _detailOwnerIsCurrent) {
        _setDetailState(() => _savingPost = false);
      }
    }
  });

  Future<void> _sharePost(
    BuildContext anchorContext,
  ) => _runDetailOwner(() async {
    if (_sharingPost) return;
    _setDetailState(() => _sharingPost = true);
    try {
      final box = anchorContext.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${widget.post.authorName ?? communityText(context, 'BIL member', 'عضو BIL')}\n\n${widget.post.body}',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } catch (_) {
      if (mounted && _detailOwnerIsCurrent) _showActionError();
    } finally {
      if (mounted && _detailOwnerIsCurrent) {
        _setDetailState(() => _sharingPost = false);
      }
    }
  });
}
