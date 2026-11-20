part of 'community_hub_page.dart';

typedef _CommunityReferenceSnapshot = ({
  int read,
  Map<String, CommunityPost> posts,
  List<CommunityPostReferenceMetadata> values,
});

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

  int _presentationRead = 0;
  Future<List<CommunityPost>>? _pendingPresentation;
  List<CommunityPost> _presentedPosts = const [];
  CommunityFeedMode? _presentedMode;
  int _referenceRead = 0;
  final _referenceReads = <String, int>{};
  final _referenceRevisions = <String, CommunityPost>{};
  Map<String, CommunityPost> _referenceTargets = const {};
  int _referenceTargetGeneration = -1;
  int? _pendingFirstRead;

  void _rememberPresentedPosts(
    List<CommunityPost> posts,
    CommunityFeedMode mode,
  ) {
    _presentedPosts = posts;
    _presentedMode = mode;
    if (_referenceTargetGeneration != _feedGeneration ||
        _pendingFirstRead == null) {
      _referenceTargets = {for (final post in posts) post.id: post};
      _referenceTargetGeneration = _feedGeneration;
      _pendingFirstRead = null;
    }
  }

  bool _matchesReferenceTarget(CommunityPost post) {
    final target = _referenceTargetGeneration == _feedGeneration
        ? _referenceTargets[post.id]
        : _presentedPosts.where((value) => value.id == post.id).firstOrNull;
    return target == null || _sameCommunityPostRevision(target, post);
  }

  CommunityPostReferenceMetadata? _referenceForPost(CommunityPost post) {
    final revision = _referenceRevisions[post.id];
    return revision != null && _sameCommunityPostRevision(revision, post)
        ? _referenceByPost[post.id]
        : null;
  }

  bool _referencesMatchPage(List<CommunityPost> posts) => !posts.any((post) {
    final revision = _referenceRevisions[post.id];
    return !_matchesReferenceTarget(post) ||
        (revision != null && !_sameCommunityPostRevision(revision, post));
  });

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
    final initialRead = ++_presentationRead;
    _pendingPresentation = null;
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
                      final read = ++_presentationRead;
                      _pendingPresentation = presentationZone.run(
                        () => _presentFirstPage(
                          visit,
                          generation,
                          read,
                          mode,
                          updated,
                        ),
                      );
                      unawaited(_pendingPresentation);
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
        if (initialRead == _presentationRead) {
          _pendingPresentation = presentationZone.run(
            () => _presentFirstPage(
              visit,
              generation,
              initialRead,
              mode,
              page,
              completeRefresh: !_cacheRefreshing,
            ),
          );
        }
      });
      visit.check();
      // A cached-refresh callback may have already superseded the cached page.
      // Await that exact presentation instead of publishing the older snapshot.
      while (mounted && visit.isCurrent() && generation == _feedGeneration) {
        final pending = _pendingPresentation;
        if (pending == null) return const <CommunityPost>[];
        final posts = await pending;
        visit.check();
        if (identical(pending, _pendingPresentation)) return posts;
      }
      return const <CommunityPost>[];
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
    List<CommunityPost> posts, {
    bool includeReferences = true,
  }) async {
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
      if (includeReferences) _refreshReferences(visit, generation, posts),
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

  Future<List<CommunityPost>> _presentFirstPage(
    _CommunityFeedVisit visit,
    int generation,
    int read,
    CommunityFeedMode mode,
    CommunityFeedModeBatch page, {
    bool completeRefresh = true,
  }) async {
    bool current() =>
        mounted &&
        visit.isCurrent() &&
        generation == _feedGeneration &&
        read == _presentationRead &&
        mode == _selectedFeedMode;
    if (!current()) return const [];
    final previous = _presentedMode == mode
        ? _presentedPosts
        : const <CommunityPost>[];
    final incoming = {for (final post in page.posts) post.id: post};
    _referenceTargets = incoming;
    _referenceTargetGeneration = generation;
    _pendingFirstRead = read;
    final retained = previous
        .where((post) {
          final next = incoming[post.id];
          return next != null && _sameCommunityPostRevision(post, next);
        })
        .toList(growable: false);
    final retainedIds = retained.map((post) => post.id).toSet();
    // Fresh feed authorization takes effect immediately. Continuity never keeps
    // a removed post or pairs a changed body/author/media revision with old chips.
    if (retained.length != previous.length) {
      setState(() {
        for (final post in previous) {
          if (!retainedIds.contains(post.id)) {
            _referenceByPost.remove(post.id);
            _referenceReads.remove(post.id);
            _referenceRevisions.remove(post.id);
            _viewCountByPost.remove(post.id);
            _commentPreviewByPost.remove(post.id);
          }
        }
        _feed = SynchronousFuture(_tagPosts(retained, mode));
      });
    }
    // A mode cache can revisit an ID with a changed body/media revision. Never
    // let metadata from that other revision become a fallback after a failed read.
    for (final post in page.posts) {
      final revision = _referenceRevisions[post.id];
      if (revision != null && !_sameCommunityPostRevision(revision, post)) {
        _referenceByPost.remove(post.id);
        _referenceRevisions.remove(post.id);
      }
    }
    final references = await _readReferences(visit, generation, page.posts);
    if (!current()) return const [];
    late List<CommunityPost> published;
    setState(() {
      if (references != null) _replaceReferences(references);
      // Other optional enrichment retains its original fresh-read semantics;
      // never extend an old identity, tier or preview past a replacement page.
      _viewCountByPost.clear();
      _commentPreviewByPost.clear();
      _membershipTierByAuthor.clear();
      (this as _FeedTabState)._authorIdentities.clear();
      (this as _FeedTabState)._authorIdentityReads.clear();
      if (completeRefresh) {
        _cacheRefreshing = false;
        _cacheRefreshFailed = false;
      }
      _hasMore = page.hasMore;
      _feedCursorPriority = page.nextPriority;
      _feedCursorCreatedAt = page.nextBefore;
      _feedCursorPostId = page.nextBeforeId;
      _pendingFirstRead = null;
      published = _tagPosts(page.posts, mode);
      _feed = SynchronousFuture(published);
      (this as _FeedTabState)._rememberModePage(mode, page);
    });
    (this as _FeedTabState)._warmOtherMode(visit, mode);
    unawaited(
      _loadFeedExtras(visit, generation, page.posts, includeReferences: false),
    );
    return published;
  }

  Future<_CommunityReferenceSnapshot?> _readReferences(
    _CommunityFeedVisit visit,
    int generation,
    List<CommunityPost> posts,
  ) async {
    if (!visit.repository.useServerCommunityReferenceParity) return null;
    final requested = {
      for (final post in posts)
        if (_matchesReferenceTarget(post)) post.id: post,
    };
    final ids = requested.keys;
    final read = ++_referenceRead;
    for (final id in ids) {
      _referenceReads[id] = read;
    }
    if (ids.isEmpty) {
      return (
        read: read,
        posts: requested,
        values: const <CommunityPostReferenceMetadata>[],
      );
    }
    try {
      final values = await visit.run(
        () => visit.repository
            .loadCommunityPostReferenceMetadata(ids.toList(growable: false))
            .timeout(const Duration(seconds: 10)),
      );
      visit.check();
      if (!mounted || generation != _feedGeneration) return null;
      return (read: read, posts: requested, values: values);
    } on Object {
      // A failed optional read is not an authoritative empty result. Existing
      // matching, authorized presentation remains until a successful retry.
      return null;
    }
  }

  void _replaceReferences(_CommunityReferenceSnapshot snapshot) {
    final accepted = snapshot.posts.keys
        .where(
          (id) =>
              _referenceReads[id] == snapshot.read &&
              _matchesReferenceTarget(snapshot.posts[id]!),
        )
        .toSet();
    // Omissions are authoritative: removed titles/tags must not survive addAll.
    for (final id in accepted) {
      _referenceByPost.remove(id);
      _referenceRevisions[id] = snapshot.posts[id]!;
    }
    for (final value in snapshot.values) {
      if (accepted.contains(value.postId)) {
        _referenceByPost[value.postId] = value;
      }
    }
  }

  Future<void> _refreshReferences(
    _CommunityFeedVisit visit,
    int generation,
    List<CommunityPost> posts,
  ) async {
    final snapshot = await _readReferences(visit, generation, posts);
    if (snapshot != null &&
        mounted &&
        visit.isCurrent() &&
        generation == _feedGeneration) {
      setState(() => _replaceReferences(snapshot));
    }
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
        final references = await presentationZone.run(
          () => _readReferences(visit, generation, page.posts),
        );
        visit.check();
        if (generation != _feedGeneration) return;
        unawaited(
          presentationZone.run(
            () => _loadFeedExtras(
              visit,
              generation,
              page.posts,
              includeReferences: false,
            ),
          ),
        );
        final known = visiblePosts.map((post) => post.id).toSet();
        final combined = [
          ...visiblePosts,
          ...page.posts.where((post) => known.add(post.id)),
        ];
        setState(() {
          if (references != null) _replaceReferences(references);
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
          _feed = SynchronousFuture(_tagPosts(combined, mode));
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

// Content revision excludes volatile counts, reactions and renewed signed URLs.
// No server edit-version is exposed by CommunityPost, so compare every visible
// content identity field before retaining the old complete presentation.
bool _sameCommunityPostRevision(CommunityPost a, CommunityPost b) {
  if ((
        a.id,
        a.authorId,
        a.body,
        a.createdAt,
        a.reviewedAt,
        a.moderationStatus,
        a.moderationVisibility,
        a.locationLabel,
      ) !=
      (
        b.id,
        b.authorId,
        b.body,
        b.createdAt,
        b.reviewedAt,
        b.moderationStatus,
        b.moderationVisibility,
        b.locationLabel,
      )) {
    return false;
  }
  final am = a.mediaItems, bm = b.mediaItems;
  if (am.length != bm.length) return false;
  for (var i = 0; i < am.length; i++) {
    final x = am[i], y = bm[i];
    if ((x.position, x.objectPath, x.mimeType, x.bytes, x.width, x.height) !=
        (y.position, y.objectPath, y.mimeType, y.bytes, y.width, y.height)) {
      return false;
    }
  }
  final ap = a.poll, bp = b.poll;
  if (ap == null || bp == null) return ap == null && bp == null;
  if ((ap.postId, ap.question, ap.allowMultiple, ap.closesAt, ap.closed) !=
          (bp.postId, bp.question, bp.allowMultiple, bp.closesAt, bp.closed) ||
      ap.options.length != bp.options.length) {
    return false;
  }
  for (var i = 0; i < ap.options.length; i++) {
    final x = ap.options[i], y = bp.options[i];
    if ((x.id, x.position, x.text) != (y.id, y.position, y.text)) return false;
  }
  return true;
}
