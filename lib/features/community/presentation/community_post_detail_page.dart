part of 'community_hub_page.dart';

class _CommunityPostDetailPage extends StatefulWidget {
  const _CommunityPostDetailPage({
    required this.post,
    required this.initialStats,
    required this.repository,
  });

  final CommunityPost post;
  final CommunityPostStats initialStats;
  final CommunityRepository repository;

  @override
  State<_CommunityPostDetailPage> createState() =>
      _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<_CommunityPostDetailPage> {
  static const _pageSize = 30;
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  late CommunityPostStats _stats = widget.initialStats;
  late Future<void> _loading = _loadInitial();
  final List<CommunityComment> _comments = [];
  CommunityComment? _replyingTo;
  String? _clientId;
  TextDirection? _composerDirection;
  String? _composerError;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _submitting = false;
  bool _likingPost = false;
  final Set<String> _busyComments = <String>{};

  Future<void> _loadInitial() async {
    final values = await Future.wait<Object>([
      widget.repository.loadPostStats([widget.post.id]),
      widget.repository.loadPostComments(widget.post.id, limit: _pageSize),
    ]);
    final stats = values[0] as List<CommunityPostStats>;
    final comments = values[1] as List<CommunityComment>;
    if (stats.length == 1) _stats = stats.single;
    _comments
      ..clear()
      ..addAll(comments);
    _hasMore = comments.length == _pageSize;
  }

  void _retry() {
    setState(() => _loading = _loadInitial());
  }

  Future<void> _refresh() async {
    final future = _loadInitial();
    setState(() => _loading = future);
    try {
      await future;
    } on Object {
      // The mounted FutureBuilder presents a stable retry state.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _comments.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final cursor = _comments.last;
      final page = await widget.repository.loadPostComments(
        widget.post.id,
        after: cursor.createdAt,
        afterId: cursor.id,
        limit: _pageSize,
      );
      if (!mounted) return;
      final known = _comments.map((comment) => comment.id).toSet();
      setState(() {
        _comments.addAll(page.where((comment) => known.add(comment.id)));
        _hasMore = page.length == _pageSize;
      });
    } catch (_) {
      if (mounted) _showActionError();
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _togglePostLike() async {
    if (_likingPost) return;
    setState(() => _likingPost = true);
    try {
      final stats = await widget.repository.setPostLiked(
        widget.post.id,
        liked: !_stats.liked,
      );
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      if (mounted) _showActionError();
    } finally {
      if (mounted) setState(() => _likingPost = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _composer.text.trim();
    if (_submitting) return;
    if (text.isEmpty) {
      setState(() {
        _composerError = communityText(
          context,
          'Write a comment first.',
          'اكتب تعليقًا أولًا.',
        );
      });
      return;
    }
    final clientId = _clientId ??= const Uuid().v4();
    setState(() {
      _submitting = true;
      _composerError = null;
    });
    try {
      final comment = await widget.repository.addPostComment(
        postId: widget.post.id,
        body: text,
        parentId: _replyingTo?.id,
        clientId: clientId,
      );
      if (!mounted) return;
      setState(() {
        final existing = _comments.indexWhere((item) => item.id == comment.id);
        if (existing < 0) {
          _comments.add(comment);
          _stats = CommunityPostStats(
            postId: _stats.postId,
            likeCount: _stats.likeCount,
            liked: _stats.liked,
            commentCount: _stats.commentCount + 1,
          );
        } else {
          _comments[existing] = comment;
        }
        _composer.clear();
        _replyingTo = null;
        _clientId = null;
      });
    } on CommunityPolicyAccessException catch (error) {
      if (!mounted) return;
      setState(() {
        _composerError = communityText(
          context,
          error.englishMessage(CommunityPolicyProtectedAction.publishing),
          error.arabicMessage(CommunityPolicyProtectedAction.publishing),
        );
      });
    } on CommunityMembershipAccessException catch (error) {
      if (!mounted) return;
      setState(() {
        _composerError = communityText(
          context,
          error.englishMessage(CommunityPolicyProtectedAction.publishing),
          error.arabicMessage(CommunityPolicyProtectedAction.publishing),
        );
      });
    } on CommunityTextPolicyException catch (error) {
      if (!mounted) return;
      setState(() {
        _composerError = error.localizedMessage(
          Localizations.localeOf(context).toLanguageTag(),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _composerError = communityText(
          context,
          'Comment was not sent. Your text is kept; retry safely.',
          'لم يُرسل التعليق. احتفظنا بالنص؛ حاول مجددًا بأمان.',
        );
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleCommentLike(CommunityComment comment) async {
    if (!_busyComments.add(comment.id)) return;
    setState(() {});
    try {
      final updated = await widget.repository.setCommentLiked(
        comment,
        liked: !comment.liked,
      );
      if (!mounted) return;
      final index = _comments.indexWhere((item) => item.id == comment.id);
      if (index >= 0) setState(() => _comments[index] = updated);
    } catch (_) {
      if (mounted) _showActionError();
    } finally {
      if (mounted) {
        setState(() => _busyComments.remove(comment.id));
      } else {
        _busyComments.remove(comment.id);
      }
    }
  }

  Future<void> _commentAction(CommunityComment comment, String action) async {
    if (action == 'reply') {
      setState(() {
        _replyingTo = comment.parentId == null
            ? comment
            : _comments.firstWhere(
                (item) => item.id == comment.parentId,
                orElse: () => comment,
              );
        _clientId = null;
        _composerError = null;
      });
      _composerFocus.requestFocus();
      return;
    }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: comment.body));
      return;
    }
    if (!_busyComments.add(comment.id)) return;
    setState(() {});
    try {
      if (action == 'delete') {
        await widget.repository.deleteComment(comment.id);
        if (!mounted) return;
        setState(() {
          final before = _comments.length;
          _comments.removeWhere(
            (item) => item.id == comment.id || item.parentId == comment.id,
          );
          final removedCount = before - _comments.length;
          _stats = CommunityPostStats(
            postId: _stats.postId,
            likeCount: _stats.likeCount,
            liked: _stats.liked,
            commentCount: _stats.commentCount > removedCount
                ? _stats.commentCount - removedCount
                : 0,
          );
        });
      } else if (action == 'report') {
        await widget.repository.reportComment(
          comment.id,
          reason: 'user_reported_from_post_detail',
        );
      } else if (action == 'block') {
        await widget.repository.blockMember(comment.authorId);
        if (!mounted) return;
        await _refresh();
      }
      if (mounted && action != 'delete' && action != 'block') {
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
    } catch (_) {
      if (mounted) _showActionError();
    } finally {
      if (mounted) {
        setState(() => _busyComments.remove(comment.id));
      } else {
        _busyComments.remove(comment.id);
      }
    }
  }

  void _showActionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          communityText(
            context,
            'Could not complete that action safely. Try again.',
            'تعذر تنفيذ الإجراء بأمان. حاول مجددًا.',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(communityText(context, 'Post', 'منشور'))),
    body: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            _comments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && _comments.isEmpty) {
          return Center(
            child: FilledButton.icon(
              key: const Key('community-post-detail-retry'),
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  key: const Key('community-post-detail-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _CommunityPostDetailHeader(
                      post: widget.post,
                      stats: _stats,
                      liking: _likingPost,
                      onLike: _togglePostLike,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      communityText(context, 'Comments', 'التعليقات'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          communityText(
                            context,
                            'No comments yet. Start a respectful conversation.',
                            'لا توجد تعليقات بعد. ابدأ حوارًا محترمًا.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final comment in _comments)
                        _CommunityCommentTile(
                          key: ValueKey(comment.id),
                          comment: comment,
                          mine:
                              comment.authorId ==
                              widget.repository.currentUserId,
                          busy: _busyComments.contains(comment.id),
                          onLike: () => _toggleCommentLike(comment),
                          onAction: (action) => _commentAction(comment, action),
                        ),
                    if (_hasMore)
                      Center(
                        child: TextButton.icon(
                          key: const Key('community-comments-load-more'),
                          onPressed: _loadingMore ? null : _loadMore,
                          icon: _loadingMore
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: Text(
                            communityText(
                              context,
                              'Load more comments',
                              'تحميل مزيد من التعليقات',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingTo != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                communityText(
                                  context,
                                  'Replying to {member}',
                                  'الرد على {member}',
                                ).replaceAll(
                                  '{member}',
                                  _replyingTo!.authorHandle == null
                                      ? _replyingTo!.authorName ??
                                            communityText(
                                              context,
                                              'BIL member',
                                              'عضو BIL',
                                            )
                                      : '@${_replyingTo!.authorHandle}',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: communityText(
                                context,
                                'Cancel reply',
                                'إلغاء الرد',
                              ),
                              onPressed: () => setState(() {
                                _replyingTo = null;
                                _clientId = null;
                              }),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('community-comment-composer'),
                              controller: _composer,
                              focusNode: _composerFocus,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 1200,
                              enabled: !_submitting,
                              textDirection:
                                  _composerDirection ??
                                  Directionality.of(context),
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (value) {
                                final direction =
                                    BilWrittenLanguageResolver.directionFor(
                                      value,
                                      fallback: Directionality.of(context),
                                    );
                                if (direction != _composerDirection ||
                                    _composerError != null) {
                                  setState(() {
                                    _composerDirection = direction;
                                    _composerError = null;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: communityText(
                                  context,
                                  'Write a comment',
                                  'اكتب تعليقًا',
                                ),
                                errorText: _composerError,
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            key: const Key('community-comment-submit'),
                            tooltip: communityText(
                              context,
                              'Send comment',
                              'إرسال التعليق',
                            ),
                            onPressed: _submitting ? null : _submitComment,
                            icon: _submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _CommunityPostDetailHeader extends StatelessWidget {
  const _CommunityPostDetailHeader({
    required this.post,
    required this.stats,
    required this.liking,
    required this.onLike,
  });

  final CommunityPost post;
  final CommunityPostStats stats;
  final bool liking;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BilAccountAvatar(radius: 21, networkUrl: post.authorAvatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName ??
                          communityText(context, 'BIL member', 'عضو BIL'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (post.authorHandle != null)
                      Text(
                        '@${post.authorHandle}',
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      '${MaterialLocalizations.of(context).formatShortDate(post.createdAt.toLocal())} · ${TimeOfDay.fromDateTime(post.createdAt.toLocal()).format(context)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.hasImage) ...[
            const SizedBox(height: 14),
            _CommunityFeedImage(post: post),
          ],
          const SizedBox(height: 14),
          SelectableText(
            post.body,
            textDirection: BilWrittenLanguageResolver.directionFor(
              post.body,
              fallback: Directionality.of(context),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                key: const Key('community-post-detail-like'),
                onPressed: liking ? null : onLike,
                icon: liking
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        stats.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                label: Text('${stats.likeCount}'),
              ),
              const SizedBox(width: 8),
              Icon(Icons.mode_comment_outlined, size: 19),
              const SizedBox(width: 5),
              Text('${stats.commentCount}'),
            ],
          ),
        ],
      ),
    ),
  );
}
