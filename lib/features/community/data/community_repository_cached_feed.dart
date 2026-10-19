part of 'community_repository.dart';

extension _CommunityCachedFeedMethods on CommunityRepository {
  Future<CommunityFeedModeBatch> _loadCommunityFeedCachedFirst({
    required CommunityFeedMode mode,
    required String locale,
    required bool Function() current,
    required void Function(CommunityFeedModeBatch) onRefresh,
    required void Function() onRefreshing,
    required void Function(Object) onRefreshError,
    int limit = 40,
  }) async {
    if (!useServerRankedCommunityFeed) {
      return loadCommunityFeedMode(mode: mode, limit: limit);
    }
    final owner = currentUserId, cache = _feedCache;
    cache.bindOwner(owner);
    final scope = '${mode.wireValue}|$locale|$limit';
    final references = await loadCommunityFeedReferences(
      mode: mode,
      limit: limit,
    );
    if (!current() || currentUserId != owner) {
      throw const CommunityOwnerOperationCancelled();
    }
    final cached = await cache.readAuthorized(
      owner,
      scope,
      references.map((row) => row.postId).toList(),
    );
    Future<CommunityFeedModeBatch> refresh() async {
      final page = await loadCommunityFeedMode(mode: mode, limit: limit);
      if (!current() || currentUserId != owner) {
        throw const CommunityOwnerOperationCancelled();
      }
      await cache.save(owner, scope, page.posts);
      return page;
    }

    if (cached.isEmpty) return refresh();
    onRefreshing();
    // Independent of optional enrichment. The visit owns the callback; an old
    // account or old filter can never replace this page on late completion.
    unawaited(
      CommunityOwnerOperation.runIndependentRead(
            client: _client,
            ownerId: owner,
            readOwner: () => currentUserId,
            isCurrentOwner: current,
            action: (_) => refresh(),
          )
          .then((page) {
            if (current()) onRefresh(page);
          })
          .catchError((Object error) {
            if (current()) onRefreshError(error);
          }),
    );
    final cursor = references.isEmpty ? null : references.last;
    return CommunityFeedModeBatch(
      posts: cached,
      references: references,
      hasMore: references.length == limit,
      nextPriority: cursor?.priority,
      nextBefore: cursor?.createdAt,
      nextBeforeId: cursor?.postId,
    );
  }
}
