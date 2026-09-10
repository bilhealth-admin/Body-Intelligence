part of 'community_hub_page.dart';

/// A private, complete history of posts authored by the signed-in member.
///
/// The public Community tab remains the all-members feed. This page makes it
/// clear where a member's pending, approved, and rejected posts can be found.
class CommunityMyPostsPage extends StatefulWidget {
  const CommunityMyPostsPage({
    required this.repository,
    this.showProfileHeader = false,
    super.key,
  });

  final CommunityRepository repository;
  final bool showProfileHeader;

  @override
  State<CommunityMyPostsPage> createState() => _CommunityMyPostsPageState();
}

class _CommunityMyPostsPageState extends State<CommunityMyPostsPage> {
  static const _pageSize = 30;
  final List<CommunityPost> _posts = [];
  late Future<void> _loading = _loadInitial();
  late Future<CommunityProfile?>? _profile = widget.showProfileHeader
      ? widget.repository.loadMyProfile()
      : null;
  DateTime? _before;
  String? _beforeId;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _deleting = false;

  void _refreshProfile() {
    if (!widget.showProfileHeader) return;
    setState(() {
      _profile = widget.repository.loadMyProfile();
    });
  }

  Widget _profileHeader() => _CommunityProfileHeader(
    repository: widget.repository,
    profile: _profile!,
    onRefresh: _refreshProfile,
  );

  Future<void> _loadInitial() async {
    final batch = await widget.repository.loadMyPosts(limit: _pageSize);
    _posts
      ..clear()
      ..addAll(batch.posts);
    _before = batch.nextBefore;
    _beforeId = batch.nextBeforeId;
    _hasMore = batch.hasMore;
  }

  Future<void> _refresh() async {
    _refreshProfile();
    final future = _loadInitial();
    setState(() {
      _loading = future;
    });
    try {
      await future;
    } on Object {
      // The error state below provides the retry action.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _before == null || _beforeId == null) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final batch = await widget.repository.loadMyPosts(
        before: _before,
        beforeId: _beforeId,
        limit: _pageSize,
      );
      if (!mounted) return;
      final known = _posts.map((post) => post.id).toSet();
      setState(() {
        _posts.addAll(batch.posts.where((post) => known.add(post.id)));
        _before = batch.nextBefore;
        _beforeId = batch.nextBeforeId;
        _hasMore = batch.hasMore;
      });
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _managePost(CommunityPost post, String action) async {
    if (action != 'delete' || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(communityText(context, 'Delete post?', 'حذف المشاركة؟')),
        content: Text(
          communityText(
            context,
            'This removes your post from Community.',
            'سيؤدي ذلك إلى إزالة مشاركتك من المجتمع.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(communityText(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(communityText(context, 'Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.repository.deletePost(post.id);
      if (!mounted) return;
      setState(() => _posts.removeWhere((item) => item.id == post.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(context, 'Post deleted.', 'تم حذف المشاركة.'),
          ),
        ),
      );
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showFailure() {
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.showProfileHeader
            ? communityText(context, 'Community profile', 'ملف المجتمع')
            : communityText(context, 'My posts', 'منشوراتي'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: widget.showProfileHeader
          ? [
              IconButton(
                onPressed: () => context.push('/community/code'),
                tooltip: communityText(
                  context,
                  'My BIL Code',
                  'رمز BIL الخاص بي',
                ),
                icon: const Icon(Icons.qr_code_2_rounded),
              ),
              IconButton(
                key: const Key('community-account-updates'),
                onPressed: () => context.push('/community/notifications'),
                tooltip: communityText(
                  context,
                  'Community updates',
                  'تحديثات المجتمع',
                ),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              _CommunityAccountMenu(
                repository: widget.repository,
                onProfileChanged: _refreshProfile,
              ),
            ]
          : null,
    ),
    body: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            _posts.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.showProfileHeader) _profileHeader(),
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        if (snapshot.hasError && _posts.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.showProfileHeader) _profileHeader(),
              Center(
                child: FilledButton.icon(
                  key: const Key('community-my-posts-retry'),
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    communityText(context, 'Retry', 'إعادة المحاولة'),
                  ),
                ),
              ),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: _posts.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.showProfileHeader) _profileHeader(),
                    const SizedBox(height: 64),
                    const Icon(Icons.article_outlined, size: 52),
                    const SizedBox(height: 16),
                    Text(
                      communityText(
                        context,
                        'Posts you publish appear here. Pending and rejected posts are visible only to you.',
                        'تظهر هنا المنشورات التي تنشرها. المنشورات المعلّقة أو المرفوضة لا يراها سواك.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.builder(
                  key: const Key('community-my-posts-list'),
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      _posts.length +
                      (_hasMore ? 1 : 0) +
                      (widget.showProfileHeader ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (widget.showProfileHeader) {
                      if (index == 0) {
                        return _profileHeader();
                      }
                      index--;
                    }
                    if (index == _posts.length) {
                      return Center(
                        child: TextButton.icon(
                          key: const Key('community-my-posts-load-more'),
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
                            communityText(context, 'Load more', 'تحميل المزيد'),
                          ),
                        ),
                      );
                    }
                    final post = _posts[index];
                    return Padding(
                      key: ValueKey(post.id),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _CommunityPostCard(
                        post: post,
                        repository: widget.repository,
                        currentUserId: widget.repository.currentUserId,
                        actionsEnabled: !_deleting,
                        showModerationStatus: true,
                        onAction: (action) => _managePost(post, action),
                      ),
                    );
                  },
                ),
        );
      },
    ),
  );
}
