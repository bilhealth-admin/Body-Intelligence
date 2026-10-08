part of '../presentation/community_hub_page.dart';

enum _CommunityProfilePrimaryTab { posts, replies, media, likes }

class _CommunityProfileActivityState {
  _CommunityProfilePrimaryTab tab = _CommunityProfilePrimaryTab.posts;

  final List<CommunityProfileReplyItem> replies = [];
  DateTime? replyBefore;
  String? replyBeforeId;
  bool replyLoaded = false;
  bool replyLoading = false;
  bool replyHasMore = false;
  Object? replyError;
  int replyGeneration = 0;

  final List<CommunityProfileLikedPost> likes = [];
  DateTime? likeBefore;
  String? likeBeforeId;
  bool likeLoaded = false;
  bool likeLoading = false;
  bool likeHasMore = false;
  Object? likeError;
  int likeGeneration = 0;

  void reset({bool preserveTab = false}) {
    final selected = tab;
    tab = preserveTab ? selected : _CommunityProfilePrimaryTab.posts;
    replyGeneration++;
    replies.clear();
    replyBefore = null;
    replyBeforeId = null;
    replyLoaded = false;
    replyLoading = false;
    replyHasMore = false;
    replyError = null;
    likeGeneration++;
    likes.clear();
    likeBefore = null;
    likeBeforeId = null;
    likeLoaded = false;
    likeLoading = false;
    likeHasMore = false;
    likeError = null;
  }
}

class _CommunityProfileMediaEntry {
  const _CommunityProfileMediaEntry({required this.post, required this.media});

  final CommunityPost post;
  final CommunityPostMedia media;
}

extension _CommunityMemberProfilePrimaryContent
    on _CommunityMemberProfilePageState {
  CommunityProfileActivityDataSource _profileActivitySource(
    _CommunityProfileVisit visit,
  ) =>
      widget.profileActivityDataSource ??
      CommunityProfileActivityRepository(visit.repository);

  bool _profileRepliesVisible(CommunityProfileOverview profile) =>
      profile.isSelf || profile.showPosts;

  Future<void> _selectProfilePrimaryTab(
    _CommunityProfilePrimaryTab tab,
    CommunityProfileOverview profile,
  ) async {
    final visit = _captureProfileVisit();
    if (visit == null || _profileActivity.tab == tab) return;
    _setProfileState(() => _profileActivity.tab = tab);
    if (tab == _CommunityProfilePrimaryTab.replies &&
        _profileRepliesVisible(profile) &&
        !_profileActivity.replyLoaded) {
      await _loadProfileReplies(reset: true);
    } else if (tab == _CommunityProfilePrimaryTab.likes &&
        profile.isSelf &&
        !_profileActivity.likeLoaded) {
      await _loadProfileLikes(reset: true);
    }
  }

  Future<void> _reloadProfileActivityAfterRefresh() async {
    final profile = _profile;
    if (profile == null || !_sameProfileOwner) return;
    switch (_profileActivity.tab) {
      case _CommunityProfilePrimaryTab.posts:
      case _CommunityProfilePrimaryTab.media:
        return;
      case _CommunityProfilePrimaryTab.replies:
        if (_profileRepliesVisible(profile)) {
          await _loadProfileReplies(reset: true);
        }
        return;
      case _CommunityProfilePrimaryTab.likes:
        if (profile.isSelf) await _loadProfileLikes(reset: true);
        return;
    }
  }

  Future<void> _loadProfileReplies({required bool reset}) async {
    final visit = _captureProfileVisit();
    final profile = _profile;
    if (visit == null ||
        profile == null ||
        !_profileRepliesVisible(profile) ||
        _profileActivity.replyLoading ||
        (!reset && !_profileActivity.replyHasMore)) {
      return;
    }
    final state = _profileActivity;
    final generation = ++state.replyGeneration;
    final before = reset ? null : state.replyBefore;
    final beforeId = reset ? null : state.replyBeforeId;
    _setProfileState(() {
      state.replyLoading = true;
      state.replyError = null;
      if (reset) {
        state.replies.clear();
        state.replyBefore = null;
        state.replyBeforeId = null;
        state.replyHasMore = false;
        state.replyLoaded = false;
      }
    });
    try {
      await visit.run(() async {
        final page = await _profileActivitySource(visit).loadReplies(
          userId: visit.targetId,
          before: before,
          beforeId: beforeId,
          limit: _CommunityMemberProfilePageState._pageSize,
        );
        visit.check();
        if (generation != state.replyGeneration) return;
        final known = state.replies.map((item) => item.comment.id).toSet();
        final incoming = page.items
            .where((item) => known.add(item.comment.id))
            .toList(growable: false);
        _setProfileState(() {
          if (reset) state.replies.clear();
          state.replies.addAll(incoming);
          state.replyBefore = page.nextBefore;
          state.replyBeforeId = page.nextBeforeId;
          state.replyHasMore = page.hasMore;
          state.replyLoaded = true;
        });
      });
    } on CommunityOwnerOperationCancelled {
      // The request belongs to an invalidated owner/target visit.
    } catch (error) {
      if (visit.isCurrent() && generation == state.replyGeneration) {
        _setProfileState(() {
          state.replyError = error;
          state.replyLoaded = true;
        });
      }
    } finally {
      if (visit.isCurrent() && generation == state.replyGeneration) {
        _setProfileState(() => state.replyLoading = false);
      }
    }
  }

  Future<void> _loadProfileLikes({required bool reset}) async {
    final visit = _captureProfileVisit();
    final profile = _profile;
    if (visit == null ||
        profile == null ||
        !profile.isSelf ||
        _profileActivity.likeLoading ||
        (!reset && !_profileActivity.likeHasMore)) {
      return;
    }
    final state = _profileActivity;
    final generation = ++state.likeGeneration;
    final before = reset ? null : state.likeBefore;
    final beforeId = reset ? null : state.likeBeforeId;
    _setProfileState(() {
      state.likeLoading = true;
      state.likeError = null;
      if (reset) {
        state.likes.clear();
        state.likeBefore = null;
        state.likeBeforeId = null;
        state.likeHasMore = false;
        state.likeLoaded = false;
      }
    });
    try {
      await visit.run(() async {
        final page = await _profileActivitySource(visit).loadLikes(
          userId: visit.targetId,
          before: before,
          beforeId: beforeId,
          limit: _CommunityMemberProfilePageState._pageSize,
        );
        visit.check();
        if (generation != state.likeGeneration) return;
        final known = state.likes.map((item) => item.post.id).toSet();
        final incoming = page.items
            .where((item) => known.add(item.post.id))
            .toList(growable: false);
        _setProfileState(() {
          if (reset) state.likes.clear();
          state.likes.addAll(incoming);
          state.likeBefore = page.nextBefore;
          state.likeBeforeId = page.nextBeforeId;
          state.likeHasMore = page.hasMore;
          state.likeLoaded = true;
        });
      });
    } on CommunityOwnerOperationCancelled {
      // The request belongs to an invalidated owner/target visit.
    } catch (error) {
      if (visit.isCurrent() && generation == state.likeGeneration) {
        _setProfileState(() {
          state.likeError = error;
          state.likeLoaded = true;
        });
      }
    } finally {
      if (visit.isCurrent() && generation == state.likeGeneration) {
        _setProfileState(() => state.likeLoading = false);
      }
    }
  }

  List<Widget> _profilePrimaryContentSlivers(CommunityProfileOverview profile) {
    final visit = _captureProfileVisit();
    if (visit == null) return const [];
    return <Widget>[
      _profilePrimaryTabs(profile),
      ...switch (_profileActivity.tab) {
        _CommunityProfilePrimaryTab.posts => _profileContentSlivers(profile),
        _CommunityProfilePrimaryTab.replies => _profileReplySlivers(
          visit,
          profile,
        ),
        _CommunityProfilePrimaryTab.media => _profileMediaSlivers(
          visit,
          profile,
        ),
        _CommunityProfilePrimaryTab.likes => _profileLikeSlivers(
          visit,
          profile,
        ),
      },
    ];
  }

  Widget _profilePrimaryTabs(CommunityProfileOverview profile) =>
      SliverToBoxAdapter(
        child: SingleChildScrollView(
          key: const Key('community-profile-primary-tabs'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _profileTabButton(
                profile,
                _CommunityProfilePrimaryTab.posts,
                const Key('community-profile-tab-posts'),
                'Posts',
                'المنشورات',
              ),
              const SizedBox(width: 8),
              _profileTabButton(
                profile,
                _CommunityProfilePrimaryTab.replies,
                const Key('community-profile-tab-replies'),
                'Replies',
                'الردود',
              ),
              const SizedBox(width: 8),
              _profileTabButton(
                profile,
                _CommunityProfilePrimaryTab.media,
                const Key('community-profile-tab-media'),
                'Media',
                'الوسائط',
              ),
              const SizedBox(width: 8),
              _profileTabButton(
                profile,
                _CommunityProfilePrimaryTab.likes,
                const Key('community-profile-tab-likes'),
                'Likes',
                'الإعجابات',
              ),
            ],
          ),
        ),
      );

  Widget _profileTabButton(
    CommunityProfileOverview profile,
    _CommunityProfilePrimaryTab tab,
    Key key,
    String english,
    String arabic,
  ) {
    final selected = _profileActivity.tab == tab;
    final label = communityText(context, english, arabic);
    return selected
        ? FilledButton.tonal(key: key, onPressed: null, child: Text(label))
        : TextButton(
            key: key,
            onPressed: () => _selectProfilePrimaryTab(tab, profile),
            child: Text(label),
          );
  }

  List<Widget> _profilePostSlivers(
    _CommunityProfileVisit visit,
    CommunityProfileOverview profile,
  ) {
    final postsVisible = profile.isSelf || profile.showPosts;
    final source = postsVisible ? _posts : const <CommunityPost>[];
    final posts = profile.isSelf
        ? source
              .where(
                (post) => switch (_momentFilter) {
                  _CommunityProfileMomentFilter.all => true,
                  _CommunityProfileMomentFilter.published =>
                    post.moderationStatus ==
                        CommunityPostModerationStatus.approved,
                  _CommunityProfileMomentFilter.pending =>
                    post.moderationStatus ==
                        CommunityPostModerationStatus.pending,
                  _CommunityProfileMomentFilter.rejected =>
                    post.moderationStatus ==
                        CommunityPostModerationStatus.rejected,
                },
              )
              .toList(growable: false)
        : source;
    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                communityText(context, 'Moments', 'اللحظات'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (profile.isSelf)
                IntrinsicWidth(
                  child: DropdownButton<_CommunityProfileMomentFilter>(
                    key: const Key('community-profile-moment-filter'),
                    value: _momentFilter,
                    isExpanded: true,
                    itemHeight: null,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: _CommunityProfileMomentFilter.all,
                        child: Text(communityText(context, 'All', 'الكل')),
                      ),
                      DropdownMenuItem(
                        value: _CommunityProfileMomentFilter.published,
                        child: Text(
                          communityText(context, 'Published', 'منشور'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: _CommunityProfileMomentFilter.pending,
                        child: Text(
                          communityText(context, 'Pending', 'قيد الانتظار'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: _CommunityProfileMomentFilter.rejected,
                        child: Text(
                          communityText(context, 'Rejected', 'مرفوض'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _setProfileState(() => _momentFilter = value);
                      }
                    },
                  ),
                ),
              Icon(
                _gridMode
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_outlined,
                size: 18,
              ),
            ],
          ),
        ),
      ),
      if (posts.isEmpty)
        _profileActivityMessage(
          key: const Key('community-profile-posts-empty'),
          icon: Icons.article_outlined,
          text: postsVisible
              ? communityText(
                  context,
                  'No visible moments yet.',
                  'لا توجد لحظات ظاهرة بعد.',
                )
              : communityText(
                  context,
                  'Moments are private on this profile.',
                  'اللحظات خاصة في هذا الملف.',
                ),
        )
      else if (_gridMode)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: .82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _CommunityProfilePostTile(
                visit: visit,
                post: posts[index],
                repository: visit.repository,
                referenceMetadata: _referenceByPost[posts[index].id],
                viewCount: _viewCounts[posts[index].id],
              ),
              childCount: posts.length,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CommunityPostCard(
                  post: posts[index],
                  repository: visit.repository,
                  ownerIsCurrent: visit.isCurrent,
                  ownerChanges: visit.changes,
                  currentUserId: visit.ownerId,
                  referenceMetadata: _referenceByPost[posts[index].id],
                  actionsEnabled: !_managingPost,
                  showModerationStatus: profile.isSelf,
                  onAction: (action) => _managePost(posts[index], action),
                ),
                if (_viewCounts.containsKey(posts[index].id))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 12,
                      end: 12,
                      bottom: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          _viewCounts[posts[index].id].toString(),
                          key: Key(
                            'community-profile-post-views-${posts[index].id}',
                          ),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (postsVisible && _hasMore) _profilePostLoadMore(),
    ];
  }
}
