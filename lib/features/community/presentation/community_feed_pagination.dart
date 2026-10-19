part of 'community_hub_page.dart';

mixin _CommunityFeedPaginationMixin on State<_FeedTab> {
  bool get _loadingMore;
  set _loadingMore(bool value);
  bool get _hasMore;
  set _hasMore(bool value);
  set _feed(Future<List<CommunityPost>> value);
  int get _feedGeneration;
  set _feedGeneration(int value);
  bool get _feedRefreshing;
  set _feedRefreshing(bool value);
  bool get _cacheRefreshing;
  set _cacheRefreshing(bool value);
  set _cacheRefreshFailed(bool value);
  Map<String, CommunityPostReferenceMetadata> get _referenceByPost;
  Map<String, int> get _viewCountByPost;
  Map<String, CommunityComment> get _commentPreviewByPost;
  Map<String, String> get _membershipTierByAuthor;
  CommunityFeedMode get _selectedFeedMode;
  int? get _feedCursorPriority;
  set _feedCursorPriority(int? value);
  DateTime? get _feedCursorCreatedAt;
  set _feedCursorCreatedAt(DateTime? value);
  String? get _feedCursorPostId;
  set _feedCursorPostId(String? value);
  _CommunityFeedVisit? _captureFeedVisit();
  List<CommunityPost> _tagPosts(
    List<CommunityPost> posts,
    CommunityFeedMode mode,
  );

  Future<List<CommunityPost>> _loadFirst({
    bool keepRefreshNotice = false,
  }) async {
    // Do not fetch cached old-session content after an injected repository's
    // owner scope was retired by a queued A -> B -> A auth transition.
    if (widget.suspendAfterOwnerChange) return const <CommunityPost>[];
    final visit = _captureFeedVisit();
    if (visit == null) return const <CommunityPost>[];
    final repository = visit.repository;
    // Presentation reads have their own owner operation. Inheriting the feed
    // RPC zone cancels their continuations as soon as that RPC finishes.
    final presentationZone = Zone.current;
    repository.invalidateCommunityModeratorStatus();
    final generation = ++_feedGeneration;
    final mode = _selectedFeedMode;
    final locale = Localizations.localeOf(context).toLanguageTag();
    _feedRefreshing = true;
    _cacheRefreshing = false;
    if (!keepRefreshNotice) _cacheRefreshFailed = false;
    _loadingMore = false;
    _feedCursorPriority = null;
    _feedCursorCreatedAt = null;
    _feedCursorPostId = null;
    try {
      late CommunityFeedModeBatch page;
      await visit.run(() async {
        final prefetched = (this as _FeedTabState)._modePrefetch.remove(mode);
        page = prefetched != null
            ? await prefetched
            : await repository
                  .loadCommunityFeedCachedFirst(
                    mode: mode,
                    locale: locale,
                    current: () =>
                        mounted &&
                        visit.isCurrent() &&
                        generation == _feedGeneration,
                    onRefresh: (updated) {
                      if (!mounted ||
                          !visit.isCurrent() ||
                          generation != _feedGeneration) {
                        return;
                      }
                      setState(() {
                        _cacheRefreshing = false;
                        _cacheRefreshFailed = false;
                        (this as _FeedTabState)._rememberModePage(
                          mode,
                          updated,
                        );
                        _feed = Future.value(_tagPosts(updated.posts, mode));
                        _hasMore = updated.hasMore;
                        _feedCursorPriority = updated.nextPriority;
                        _feedCursorCreatedAt = updated.nextBefore;
                        _feedCursorPostId = updated.nextBeforeId;
                      });
                      unawaited(
                        presentationZone.run(
                          () =>
                              _loadFeedExtras(visit, generation, updated.posts),
                        ),
                      );
                    },
                    onRefreshing: () {
                      if (mounted &&
                          visit.isCurrent() &&
                          generation == _feedGeneration) {
                        setState(() => _cacheRefreshing = true);
                      }
                    },
                    onRefreshError: (_) {
                      if (mounted &&
                          visit.isCurrent() &&
                          generation == _feedGeneration) {
                        setState(() {
                          _cacheRefreshing = false;
                          _cacheRefreshFailed = true;
                        });
                      }
                    },
                    limit: _FeedTabState._pageSize,
                  )
                  .timeout(const Duration(seconds: 15));
        visit.check();
        // A direct successful network read has no cached-refresh callback.
        if (keepRefreshNotice && !_cacheRefreshing) _cacheRefreshFailed = false;
        visit.check();
        if (generation != _feedGeneration) return;
        _referenceByPost.clear();
        _viewCountByPost.clear();
        _commentPreviewByPost.clear();
        _membershipTierByAuthor.clear();
        (this as _FeedTabState)._authorIdentities.clear();
        (this as _FeedTabState)._authorIdentityReads.clear();
        unawaited(
          presentationZone.run(
            () => _loadFeedExtras(visit, generation, page.posts),
          ),
        );
        _hasMore = page.hasMore;
        _feedCursorPriority = page.nextPriority;
        _feedCursorCreatedAt = page.nextBefore;
        _feedCursorPostId = page.nextBeforeId;
      });
      visit.check();
      if (generation == _feedGeneration) {
        (this as _FeedTabState)._rememberModePage(mode, page);
        (this as _FeedTabState)._warmOtherMode(visit, mode);
      }
      return _tagPosts(page.posts, mode);
    } on CommunityOwnerOperationCancelled {
      return const <CommunityPost>[];
    } finally {
      if (visit.isCurrent() && generation == _feedGeneration) {
        _feedRefreshing = false;
      }
    }
  }

  Future<void> _loadFeedExtras(
    _CommunityFeedVisit visit,
    int generation,
    List<CommunityPost> posts,
  ) async {
    final repository = visit.repository;
    if (!repository.useServerCommunityReferenceParity || posts.isEmpty) return;
    final ids = posts.map((post) => post.id).toList(growable: false);
    final authors = posts
        .map((post) => post.authorId)
        .toSet()
        .toList(growable: false);
    Future<void> apply<T>(
      Future<T> Function() load,
      void Function(T) update,
    ) async {
      try {
        await visit.run(() async {
          final value = await load().timeout(const Duration(seconds: 10));
          visit.check();
          if (!mounted || generation != _feedGeneration) return;
          setState(() => update(value));
        });
      } on Object {
        // Missing decoration never hides an authorized feed or becomes a
        // fake subscription/reputation value. A later refresh retries it.
      }
    }

    await Future.wait([
      (this as _FeedTabState)._loadAuthorIdentities(visit, generation, posts),
      apply(
        () => repository.loadCommunityPostReferenceMetadata(ids),
        (values) => _referenceByPost.addEntries(
          values.map((value) => MapEntry(value.postId, value)),
        ),
      ),
      apply(
        () => repository.loadCommunityPostViewCounts(ids),
        _viewCountByPost.addAll,
      ),
      apply(
        () => repository.loadCommunityFeedCommentPreviews(ids),
        _commentPreviewByPost.addAll,
      ),
      apply(
        () => repository.loadVisibleMembershipTiers(authors),
        _membershipTierByAuthor.addAll,
      ),
    ]);
  }

  Future<void> _loadMore(List<CommunityPost> visiblePosts) async {
    final visit = _captureFeedVisit();
    if (visit == null ||
        _loadingMore ||
        _feedRefreshing ||
        _cacheRefreshing ||
        !_hasMore ||
        visiblePosts.isEmpty ||
        _feedCursorPriority == null ||
        _feedCursorCreatedAt == null ||
        _feedCursorPostId == null) {
      return;
    }
    final repository = visit.repository;
    final generation = _feedGeneration;
    final mode = _selectedFeedMode;
    setState(() => _loadingMore = true);
    final presentationZone = Zone.current;
    try {
      await visit.run(() async {
        final page = await repository.loadCommunityFeedMode(
          mode: mode,
          beforePriority: _feedCursorPriority,
          before: _feedCursorCreatedAt,
          beforeId: _feedCursorPostId,
          limit: _FeedTabState._pageSize,
        );
        visit.check();
        unawaited(
          presentationZone.run(
            () => _loadFeedExtras(visit, generation, page.posts),
          ),
        );
        visit.check();
        if (generation != _feedGeneration) return;
        final known = visiblePosts.map((post) => post.id).toSet();
        final combined = [
          ...visiblePosts,
          ...page.posts.where((post) => known.add(post.id)),
        ];
        setState(() {
          (this as _FeedTabState)._rememberModePage(
            mode,
            CommunityFeedModeBatch(
              posts: combined,
              references: page.references,
              hasMore: page.hasMore,
              nextPriority: page.nextPriority,
              nextBefore: page.nextBefore,
              nextBeforeId: page.nextBeforeId,
            ),
          );
          _feed = Future.value(_tagPosts(combined, mode));
          _hasMore = page.hasMore;
          _feedCursorPriority = page.nextPriority;
          _feedCursorCreatedAt = page.nextBefore;
          _feedCursorPostId = page.nextBeforeId;
        });
      });
    } on CommunityOwnerOperationCancelled {
      // An old owner/page cannot append into the current feed.
    } catch (_) {
      if (!mounted || !visit.isCurrent() || generation != _feedGeneration) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not load older posts. Try again.',
              'تعذر تحميل المنشورات الأقدم. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (visit.isCurrent() && generation == _feedGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }
}

extension _CommunityFeedScrollRestore on _FeedTabState {
  void _rememberOffset() {
    if (!_restoreOffset && _scroll.hasClients) {
      widget.preview.scrollOffsets[_selectedFeedMode] = _scroll.offset;
    }
  }

  void _resumeFeed(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _captureFeedVisit() == null) {
      return;
    }
    widget.preview.refreshIfExpired();
    _setFeedState(() => _policyState = widget.preview.policy);
    unawaited(_refresh());
  }

  void _restoreScrollWhenReady(
    _CommunityFeedVisit visit, {
    required bool matched,
    required bool loading,
  }) {
    if (!_restoreOffset || !matched || loading) return;
    _restoreOffset = false;
    final generation = _feedGeneration;
    final target = _targetOffset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !visit.isCurrent() ||
          generation != _feedGeneration ||
          !_scroll.hasClients) {
        return;
      }
      final bounded = target
          .clamp(0, _scroll.position.maxScrollExtent)
          .toDouble();
      if ((_scroll.offset - bounded).abs() > .5) {
        _scroll.jumpTo(bounded);
      }
    });
  }
}
