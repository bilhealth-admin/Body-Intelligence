part of 'community_hub_page.dart';

extension _CommunityFeedRendering on _FeedTabState {
  Widget _renderFeed(BuildContext context) {
    if (_entryWelcomeVisible) {
      return const CommunityWelcome();
    }
    return Stack(
      children: [
        FutureBuilder<List<CommunityPost>>(
          future: _feed,
          builder: (context, snapshot) {
            final visit = _captureFeedVisit();
            if (visit == null) {
              return const _CommunityProfileOwnerChangedBody();
            }
            final matched =
                snapshot.data != null &&
                _postModes[snapshot.data!] == _selectedFeedMode;
            final posts = widget.suspendAfterOwnerChange || !matched
                ? const <CommunityPost>[]
                : snapshot.data!
                      .map(
                        (post) =>
                            _authorIdentities[post.authorId]?.applyTo(post) ??
                            post,
                      )
                      .toList(growable: false);
            final failed =
                snapshot.connectionState == ConnectionState.done &&
                snapshot.hasError;
            final loading = snapshot.connectionState != ConnectionState.done;
            _restoreScrollWhenReady(visit, matched: matched, loading: loading);
            return NotificationListener<ScrollUpdateNotification>(
              onNotification: (event) {
                if (event.depth == 0 && event.dragDetails != null) {
                  _restoreOffset = false;
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: _refreshSelectedFeed,
                child: Semantics(
                  key: const Key('community-public-feed'),
                  value:
                      _selectedTopic?.slug ?? _feedModeLabel(_selectedFeedMode),
                  label: communityText(
                    context,
                    'Shared with BIL members',
                    'مشاركات أعضاء BIL',
                  ),
                  child: CustomScrollView(
                    controller: _scroll,
                    key: PageStorageKey(
                      'community-feed-scroll-${visit.ownerId}-${widget.preview.visit.epoch}-${widget.preview.locale}-${_selectedFeedMode.wireValue}',
                    ),
                    // Keep the post surface pinned during pull-to-refresh.
                    // The refresh indicator still receives overscroll while
                    // ClampingScrollPhysics avoids iOS bounce moving the feed.
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: CommunityPolicyNotice(
                          state: _policyState!,
                          initialState:
                              identical(_policyState, widget.preview.policy)
                              ? widget.preview.knownPolicy
                              : null,
                          onReview: () => _reviewPolicy(visit),
                          onRetry: () => _refreshPolicyState(visit),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _CommunityFeedReferenceHeader(
                          profile: widget.preview.profile,
                          initialProfile: widget.preview.knownProfile,
                          initialTopics: widget.preview.knownTopics,
                          repository: visit.repository,
                          posts: posts,
                          topics: _suggestedTopics,
                          enabled:
                              !_openingComposer &&
                              !_managingPost &&
                              !widget.suspendAfterOwnerChange,
                          ownerIsCurrent: visit.isCurrent,
                          onCompose: ({tag, circle}) => _openComposer(
                            tag: tag ?? _selectedTopic?.slug,
                            circle: circle,
                          ),
                          selectedTopic: _selectedTopic?.slug,
                          onSelectTopic: _selectTopic,
                          onOpenCircles: widget.onOpenCircles,
                        ),
                      ),
                      if (_selectedTopic case final topic?)
                        _CommunityInlineTopicFeed(
                          key: _topicFeedKey,
                          topic: topic,
                          visit: visit,
                          metadata: _referenceByPost,
                          identities: _authorIdentities,
                          viewCounts: _viewCountByPost,
                          previews: _commentPreviewByPost,
                          tiers: _membershipTierByAuthor,
                          actionsEnabled: !_openingComposer && !_managingPost,
                          onPostsLoaded: (loaded) => unawaited(
                            _loadFeedExtras(visit, _feedGeneration, loaded),
                          ),
                          onMutation: () {
                            _topicMutated = true;
                            _modeReadEpoch++;
                            _modePages.clear();
                            _modePrefetch.clear();
                          },
                          onAction: (post, action) async {
                            await _managePost(post, action);
                            if (action != 'report') {
                              await _topicFeedKey.currentState?.refresh();
                            }
                          },
                        )
                      else ...[
                        if (!loading &&
                            posts.isEmpty &&
                            _selectedFeedMode == CommunityFeedMode.explore)
                          SliverToBoxAdapter(
                            child: _CommunityFeedTopicSuggestions(
                              topics: _suggestedTopics,
                              initialTopics:
                                  identical(
                                    _suggestedTopics,
                                    widget.preview.topics,
                                  )
                                  ? widget.preview.knownTopics
                                  : null,
                              onOpen: _openTopic,
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            key: const Key('community-refresh-slot'),
                            height: 3,
                            child: (loading && matched) || _cacheRefreshing
                                ? const LinearProgressIndicator()
                                : const SizedBox.shrink(),
                          ),
                        ),
                        if (_cacheRefreshFailed)
                          SliverToBoxAdapter(
                            child: CommunityFeedRefreshNotice(
                              onRetry: _refresh,
                            ),
                          ),
                        if (failed)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _InlineError(onRetry: _refresh),
                          )
                        else if (loading && !matched)
                          const SliverToBoxAdapter(
                            child: _CommunityFeedSkeleton(
                              key: Key('community-feed-cold-placeholder'),
                            ),
                          )
                        else if (posts.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                96,
                              ),
                              child: Center(
                                child: Text(
                                  _emptyFeedMessage(),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              _hasMore ? 12 : 100,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final post = posts[index];
                                return Padding(
                                  key: ValueKey(post.id),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _CommunityPostCard(
                                    post: post,
                                    repository: visit.repository,
                                    ownerIsCurrent: visit.isCurrent,
                                    ownerChanges: visit.changes,
                                    currentUserId: visit.ownerId,
                                    referenceMetadata:
                                        _referenceByPost[post.id],
                                    viewCount: _viewCountByPost[post.id],
                                    commentPreview:
                                        _commentPreviewByPost[post.id],
                                    authorMembershipTier:
                                        _membershipTierByAuthor[post.authorId],
                                    actionsEnabled:
                                        !_openingComposer && !_managingPost,
                                    onMutation: () {
                                      _modeReadEpoch++;
                                      _modePages.clear();
                                      _modePrefetch.clear();
                                    },
                                    onAction: (value) =>
                                        _managePost(post, value),
                                  ),
                                );
                              }, childCount: posts.length),
                            ),
                          ),
                        if (!failed && matched && posts.isNotEmpty && _hasMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                100,
                              ),
                              child: Center(
                                child: TextButton.icon(
                                  key: const Key('community-feed-load-more'),
                                  onPressed:
                                      _loadingMore ||
                                          _feedRefreshing ||
                                          _cacheRefreshing
                                      ? null
                                      : () => _loadMore(posts),
                                  icon: _loadingMore
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const BilGlassPressFeedback(
                                          child: Icon(
                                            Icons.expand_more_rounded,
                                          ),
                                        ),
                                  label: Text(
                                    communityText(
                                      context,
                                      'Load older posts',
                                      'تحميل منشورات أقدم',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
