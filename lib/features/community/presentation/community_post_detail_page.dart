part of 'community_hub_page.dart';

class _CommunityPostDetailPage extends StatefulWidget {
  const _CommunityPostDetailPage({
    required this.post,
    required this.initialStats,
    required this.repository,
    this.referenceMetadata,
  });

  final CommunityPost post;
  final CommunityPostStats initialStats;
  final CommunityRepository repository;
  final CommunityPostReferenceMetadata? referenceMetadata;

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
  String? _clientBody;
  DateTime? _after;
  String? _afterId;
  int _loadGeneration = 0;
  bool _refreshing = false;
  TextDirection? _composerDirection;
  String? _composerError;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _submitting = false;
  bool _likingPost = false;
  bool _savingPost = false;
  bool _sharingPost = false;
  late bool _savedPost = widget.post.saved;
  bool _followBusy = false;
  int? _viewCount;
  CommunityProfileOverview? _authorProfile;
  String? _authorMembershipTier;
  final Set<String> _busyComments = <String>{};
  final Set<String> _membershipTierResolvedUsers = <String>{};
  final Map<String, String> _membershipTierByUser = <String, String>{};
  final Set<String> _expandedThreads = <String>{};
  final Set<String> _loadingReplyThreads = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_recordView());
    unawaited(_loadAuthorProfile());
    unawaited(_loadAuthorMembershipTier());
  }

  Future<void> _loadAuthorMembershipTier() async {
    if (!widget.repository.useServerCommunityReferenceParity) return;
    try {
      final tiers = await widget.repository.loadVisibleMembershipTiers([
        widget.post.authorId,
      ]);
      if (mounted) {
        setState(() => _authorMembershipTier = tiers[widget.post.authorId]);
      }
    } on Object {
      // Membership tier is opt-in presentation and never blocks post reading.
    }
  }

  Future<void> _loadAuthorProfile() async {
    if (!widget.repository.useServerCommunityReferenceParity) return;
    if (widget.post.authorId == widget.repository.currentUserId) return;
    try {
      final profile = await widget.repository.loadProfileOverview(
        widget.post.authorId,
      );
      if (mounted) setState(() => _authorProfile = profile);
    } on Object {
      // The post remains readable if the relationship affordance cannot load.
    }
  }

  Future<void> _toggleAuthorFollow() async {
    final profile = _authorProfile;
    if (profile == null ||
        profile.isSelf ||
        _followBusy ||
        (!profile.viewerFollows && !profile.allowFollows)) {
      return;
    }
    setState(() => _followBusy = true);
    try {
      if (profile.viewerFollows) {
        await widget.repository.unfollow(profile.userId);
      } else {
        await widget.repository.follow(profile.userId);
      }
      final refreshed = await widget.repository.loadProfileOverview(
        profile.userId,
      );
      if (mounted) setState(() => _authorProfile = refreshed);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not update follow state.',
                'تعذر تحديث حالة المتابعة.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _recordView() async {
    if (!widget.repository.useServerCommunityReferenceParity) return;
    try {
      final count = await widget.repository.recordCommunityPostView(
        widget.post.id,
      );
      if (mounted) setState(() => _viewCount = count);
    } on Object {
      // Reading a post remains available when non-critical view analytics fail.
    }
  }

  Future<Map<String, String>> _fetchMembershipTiers(
    Iterable<CommunityComment> comments,
  ) async {
    if (!widget.repository.useServerCommunityReferenceParity) {
      return const <String, String>{};
    }
    final ids = comments
        .map((comment) => comment.authorId)
        .where((id) => !_membershipTierResolvedUsers.contains(id))
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const <String, String>{};
    try {
      return await widget.repository.loadCommentMembershipTiers(ids);
    } on Object {
      // Tier display is optional and must never block comment reading.
      return const <String, String>{};
    }
  }

  Future<void> _loadInitial() async {
    final generation = ++_loadGeneration;
    _refreshing = true;
    _loadingMore = false;
    try {
      final values = await Future.wait<Object>([
        widget.repository.loadPostStats([widget.post.id]),
        widget.repository.loadPostCommentThreads(
          widget.post.id,
          limit: _pageSize,
        ),
      ]);
      final stats = values[0] as List<CommunityPostStats>;
      final threads = values[1] as List<CommunityCommentThread>;
      final loadedComments = <CommunityComment>[
        for (final thread in threads) ...[thread.root, ...thread.replies],
      ];
      final tiers = await _fetchMembershipTiers(loadedComments);
      if (!mounted || generation != _loadGeneration) return;
      if (stats.length == 1) _stats = stats.single;
      _comments
        ..clear()
        ..addAll(loadedComments);
      _membershipTierResolvedUsers
        ..clear()
        ..addAll(loadedComments.map((comment) => comment.authorId));
      _membershipTierByUser
        ..clear()
        ..addAll(tiers);
      _expandedThreads.removeWhere(
        (rootId) => !_comments.any((comment) => comment.id == rootId),
      );
      _hasMore = threads.length == _pageSize;
      _after = threads.lastOrNull?.root.createdAt;
      _afterId = threads.lastOrNull?.root.id;
    } finally {
      if (generation == _loadGeneration) _refreshing = false;
    }
  }

  void _retry() {
    setState(() {
      _loading = _loadInitial();
    });
  }

  Future<void> _refresh() async {
    if (_submitting || _busyComments.isNotEmpty || _likingPost) return;
    final future = _loadInitial();
    setState(() {
      _loading = future;
    });
    try {
      await future;
    } on Object {
      // The mounted FutureBuilder presents a stable retry state.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore ||
        _refreshing ||
        !_hasMore ||
        _after == null ||
        _afterId == null) {
      return;
    }
    final generation = _loadGeneration;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.loadPostCommentThreads(
        widget.post.id,
        after: _after,
        afterId: _afterId,
        limit: _pageSize,
      );
      final loaded = <CommunityComment>[
        for (final thread in page) ...[thread.root, ...thread.replies],
      ];
      final tiers = await _fetchMembershipTiers(loaded);
      if (!mounted || generation != _loadGeneration) return;
      final known = _comments.map((comment) => comment.id).toSet();
      setState(() {
        _membershipTierResolvedUsers.addAll(
          loaded.map((comment) => comment.authorId),
        );
        _membershipTierByUser.addAll(tiers);
        for (final thread in page) {
          if (known.add(thread.root.id)) {
            _comments.add(thread.root);
          }
          for (final reply in thread.replies) {
            if (known.add(reply.id)) _comments.add(reply);
          }
        }
        _hasMore = page.length == _pageSize;
        if (page.isNotEmpty) {
          _after = page.last.root.createdAt;
          _afterId = page.last.root.id;
        }
      });
    } catch (_) {
      if (mounted && generation == _loadGeneration) _showActionError();
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  List<CommunityComment> get _rootComments {
    final roots =
        _comments
            .where((comment) => comment.parentId == null)
            .toList(growable: false)
          ..sort((a, b) {
            final byTime = a.createdAt.compareTo(b.createdAt);
            return byTime == 0 ? a.id.compareTo(b.id) : byTime;
          });
    return roots;
  }

  List<CommunityComment> _loadedReplies(String rootId) {
    final replies =
        _comments
            .where((comment) => comment.parentId == rootId)
            .toList(growable: false)
          ..sort((a, b) {
            final byTime = a.createdAt.compareTo(b.createdAt);
            return byTime == 0 ? a.id.compareTo(b.id) : byTime;
          });
    return replies;
  }

  Future<void> _loadMoreReplies(CommunityComment root) async {
    if (!_loadingReplyThreads.add(root.id)) return;
    setState(() => _expandedThreads.add(root.id));
    try {
      final loaded = _loadedReplies(root.id);
      if (loaded.length >= root.replyCount) return;
      final last = loaded.lastOrNull;
      final page = await widget.repository.loadCommentReplies(
        root.id,
        after: last?.createdAt,
        afterId: last?.id,
        limit: 20,
      );
      final tiers = await _fetchMembershipTiers(page);
      if (!mounted) return;
      final known = _comments.map((comment) => comment.id).toSet();
      setState(() {
        _membershipTierResolvedUsers.addAll(
          page.map((comment) => comment.authorId),
        );
        _membershipTierByUser.addAll(tiers);
        _comments.addAll(page.where((comment) => known.add(comment.id)));
      });
    } catch (_) {
      if (mounted) _showActionError();
    } finally {
      if (mounted) {
        setState(() => _loadingReplyThreads.remove(root.id));
      } else {
        _loadingReplyThreads.remove(root.id);
      }
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
  Future<void> _togglePostSaved() async {
    if (_savingPost) return;
    setState(() => _savingPost = true);
    try {
      final state = await widget.repository.setPostSaved(
        widget.post.id,
        saved: !_savedPost,
      );
      if (mounted) setState(() => _savedPost = state.saved);
    } catch (_) {
      if (mounted) _showActionError();
    } finally {
      if (mounted) setState(() => _savingPost = false);
    }
  }

  Future<void> _sharePost(BuildContext anchorContext) async {
    if (_sharingPost) return;
    setState(() => _sharingPost = true);
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
    } catch (_) {
      if (mounted) _showActionError();
    } finally {
      if (mounted) setState(() => _sharingPost = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _composer.text.trim();
    if (_submitting || _refreshing) return;
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
    // An unchanged retry reuses its id. Editing after an uncertain failure is
    // a different payload and must not collide with the server's idempotency
    // guard (which correctly rejects one id used for two different bodies).
    if (_clientBody != text) {
      _clientBody = text;
      _clientId = null;
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
      final tiers = await _fetchMembershipTiers([comment]);
      if (!mounted) return;
      setState(() {
        _membershipTierResolvedUsers.add(comment.authorId);
        _membershipTierByUser.addAll(tiers);
        final existing = _comments.indexWhere((item) => item.id == comment.id);
        if (existing < 0) {
          _comments.add(comment);
          final rootId = comment.parentId;
          if (rootId != null) {
            final rootIndex = _comments.indexWhere(
              (item) => item.id == rootId && item.parentId == null,
            );
            if (rootIndex >= 0) {
              _comments[rootIndex] = _comments[rootIndex].copyWith(
                replyCount: _comments[rootIndex].replyCount + 1,
              );
            }
            _expandedThreads.add(rootId);
          }
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
        _composerDirection = null;
        _replyingTo = null;
        _clientId = null;
        _clientBody = null;
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
        _replyingTo = comment;
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
          final isRoot = comment.parentId == null;
          final removedCount = isRoot ? comment.replyCount + 1 : 1;
          final rootId = comment.parentId;
          _comments.removeWhere(
            (item) => item.id == comment.id || item.parentId == comment.id,
          );
          if (!isRoot && rootId != null) {
            final rootIndex = _comments.indexWhere(
              (item) => item.id == rootId && item.parentId == null,
            );
            if (rootIndex >= 0) {
              _comments[rootIndex] = _comments[rootIndex].copyWith(
                replyCount: _comments[rootIndex].replyCount > 0
                    ? _comments[rootIndex].replyCount - 1
                    : 0,
              );
            }
          } else {
            _expandedThreads.remove(comment.id);
            _loadingReplyThreads.remove(comment.id);
          }
          if (_replyingTo?.id == comment.id ||
              _replyingTo?.parentId == comment.id) {
            _replyingTo = null;
            _clientId = null;
          }
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
        // The server filters blocked members and their reply threads. Refresh
        // only after releasing this mutation's busy guard.
        _busyComments.remove(comment.id);
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

  void _setDetailState(VoidCallback callback) => setState(callback);

  @override
  Widget build(BuildContext context) =>
      _CommunityPostDetailRendering(this).buildCommunityPostDetail(context);
}
