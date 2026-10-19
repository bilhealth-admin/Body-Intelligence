part of 'community_hub_page.dart';

extension _CommunityFeedAuthorIdentity on _FeedTabState {
  Future<void> _refreshVisibleAuthorIdentities() async {
    final visit = _captureFeedVisit();
    if (visit == null || !visit.repository.useServerCommunityReferenceParity) {
      return;
    }
    final generation = _feedGeneration, future = _feed;
    try {
      final posts = await future;
      if (!mounted || !visit.isCurrent() || !identical(future, _feed)) return;
      await _loadAuthorIdentities(visit, generation, posts);
    } on Object {
      /* Existing feed/error presentation remains authoritative. */
    }
  }

  Future<void> _loadAuthorIdentities(
    _CommunityFeedVisit visit,
    int generation,
    List<CommunityPost> posts,
  ) async {
    if (posts.isEmpty) return;
    final ids = posts.map((p) => p.authorId).toSet();
    final read = ++_authorIdentityRead;
    for (final id in ids) {
      _authorIdentityReads[id] = read;
    }
    try {
      await visit.run(() async {
        final identities = await visit.repository
            .loadPostAuthorIdentities(ids.toList())
            .timeout(const Duration(seconds: 10));
        visit.check();
        if (!mounted || generation != _feedGeneration) return;
        final accepted = identities
            .where(
              (v) =>
                  ids.contains(v.userId) &&
                  _authorIdentityReads[v.userId] == read,
            )
            .toList();
        if (accepted.isEmpty) return;
        _setFeedState(() {
          for (final identity in accepted) {
            _authorIdentities[identity.userId] = identity;
          }
        });
      });
    } on Object {
      // A failed identity read never fabricates a new name or hides allowed posts.
    }
  }
}
