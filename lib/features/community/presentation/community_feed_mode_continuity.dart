part of 'community_hub_page.dart';

class _FeedModePage {
  _FeedModePage(this.page) : age = Stopwatch()..start();
  final CommunityFeedModeBatch page;
  final Stopwatch age;
  bool get fresh => age.elapsed < const Duration(seconds: 30);
}

extension _CommunityFeedModeContinuity on _FeedTabState {
  void _rememberModePage(CommunityFeedMode mode, CommunityFeedModeBatch page) {
    if (_captureFeedVisit() != null) {
      _modePages[mode] = _FeedModePage(page);
    }
  }

  void _warmOtherMode(_CommunityFeedVisit visit, CommunityFeedMode current) {
    if (!visit.repository.useServerRankedCommunityFeed) return;
    if (current != CommunityFeedMode.explore &&
        current != CommunityFeedMode.following) {
      return;
    }
    final mode = current == CommunityFeedMode.following
        ? CommunityFeedMode.explore
        : CommunityFeedMode.following;
    if (_modePages[mode]?.fresh == true || _modePrefetch.containsKey(mode)) {
      return;
    }
    final epoch = _modeReadEpoch;
    // Real server-authorized reads only. No local ranking or cross-owner cache.
    final future = visit
        .run(
          () => visit.repository.loadCommunityFeedMode(
            mode: mode,
            limit: _FeedTabState._pageSize,
          ),
        )
        .timeout(const Duration(seconds: 15));
    _modePrefetch[mode] = future;
    unawaited(
      future
          .then<void>(
            (page) {
              if (visit.isCurrent() && epoch == _modeReadEpoch) {
                _rememberModePage(mode, page);
              }
            },
            onError: (Object _, StackTrace _) {
              // A failed background warmup is retried by the explicit tab visit.
            },
          )
          .whenComplete(() {
            if (identical(_modePrefetch[mode], future)) {
              _modePrefetch.remove(mode);
            }
          }),
    );
  }

  bool _useReadyMode(CommunityFeedMode mode) {
    final cached = _modePages[mode];
    if (cached == null || !cached.fresh || _captureFeedVisit() == null) {
      return false;
    }
    final page = cached.page;
    _feedGeneration++;
    _feedRefreshing = false;
    _cacheRefreshing = false;
    _cacheRefreshFailed = false;
    _loadingMore = false;
    _hasMore = page.hasMore;
    _feedCursorPriority = page.nextPriority;
    _feedCursorCreatedAt = page.nextBefore;
    _feedCursorPostId = page.nextBeforeId;
    _feed = SynchronousFuture(_tagPosts(page.posts, mode));
    return true;
  }
}

/// Honest first-load placeholder; existing content is never replaced by a spinner.
class _CommunityFeedSkeleton extends StatelessWidget {
  const _CommunityFeedSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: communityText(context, 'Loading posts', 'تحميل المنشورات'),
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BilPearlMaterialCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final width in [
                  120.0,
                  double.infinity,
                  double.infinity,
                  180.0,
                ])
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    height: 14,
                    width: width,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
