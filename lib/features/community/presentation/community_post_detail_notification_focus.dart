part of 'community_hub_page.dart';

extension _CommunityPostDetailNotificationFocus
    on _CommunityPostDetailPageState {
  Future<void> _loadNotificationFocus(int generation) =>
      _runDetailOwner(() async {
        final loader = widget.notificationLoader;
        final commentId = widget.focusCommentId;
        if (loader == null || commentId == null) return;
        final focusGeneration = ++_focusGeneration;
        bool current() =>
            mounted &&
            _detailOwnerIsCurrent &&
            generation == _loadGeneration &&
            focusGeneration == _focusGeneration;
        _setDetailState(() {
          _focusLoading = true;
          _focusUnavailable = false;
          _focusFailed = false;
        });
        try {
          final focus = await loader.loadFocus(
            widget.post.id,
            commentId,
            isCurrent: current,
          );
          _detailOwnerScope.check();
          if (!current()) return;
          if (widget.verifyAccess != null && !await widget.verifyAccess!()) {
            return;
          }
          _detailOwnerScope.check();
          if (!current()) return;
          _setDetailState(() {
            _notificationFocus = focus;
            _focusUnavailable = focus == null;
            if (focus != null) {
              final rows = [focus.thread.root, ...focus.thread.replies];
              final updated = {for (final row in _comments) row.id: row};
              for (final row in rows) {
                updated[row.id] = row;
              }
              _comments
                ..clear()
                ..addAll(updated.values);
              if (focus.commentId != focus.thread.root.id) {
                _expandedThreads.add(focus.thread.root.id);
              }
            }
          });
          if (focus != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final target = _notificationFocusKey.currentContext;
              if (!current() || target == null) return;
              unawaited(
                Scrollable.ensureVisible(
                  target,
                  alignment: .12,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                ),
              );
            });
          }
        } on CommunityOwnerOperationCancelled {
          // Cancel/navigation/account change retires the scan, never a new request.
        } on Object {
          if (current()) _setDetailState(() => _focusFailed = true);
        } finally {
          if (current()) _setDetailState(() => _focusLoading = false);
        }
      }).onError<CommunityOwnerOperationCancelled>((_, _) {
        // A replaced account/route retires an unawaited scan without repainting.
      });

  void _cancelNotificationFocus() {
    _setDetailState(() {
      _focusGeneration++;
      _focusLoading = false;
      _focusFailed = true;
    });
  }
}
