part of 'community_hub_page.dart';

/// Public content reader, separate from the author's private moderation receipt.
class CommunityNotificationContentPage extends StatefulWidget {
  const CommunityNotificationContentPage({
    required this.postId,
    this.commentId,
    this.validQuery = true,
    this.repository,
    this.client,
    super.key,
  });
  final String postId;
  final String? commentId;
  final bool validQuery;
  final CommunityRepository? repository;
  final SupabaseClient? client;
  @override
  State<CommunityNotificationContentPage> createState() =>
      _CommunityNotificationContentPageState();
}

class _CommunityNotificationContentPageState
    extends State<CommunityNotificationContentPage>
    with WidgetsBindingObserver {
  CommunityRepository? _repository;
  CommunityAccountVisit? _visit;
  late Future<_CommunityNotificationPost?> _loading;
  int _generation = 0;
  Object? _accessError;
  bool _accessRemoved = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bind();
  }

  void _bind() {
    SupabaseClient? client =
        widget.client ?? widget.repository?.communitySocialClient;
    if (client == null && AppEnvironment.supabaseRuntimeReady) {
      try {
        if (Supabase.instance.isInitialized) client = Supabase.instance.client;
      } on Object {
        /* Unconfigured runtime. */
      }
    }
    _repository =
        widget.repository ??
        (client == null ? null : CommunityRepository(client));
    _visit = CommunityAccountVisit(
      repository: _repository,
      client: client,
      onChanged: () {
        if (mounted) _retry();
      },
    );
    _loading = _load();
  }

  @override
  void didUpdateWidget(covariant CommunityNotificationContentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.commentId != widget.commentId ||
        oldWidget.validQuery != widget.validQuery ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.client, widget.client)) {
      _visit?.dispose();
      _accessRemoved = false;
      _accessError = null;
      _bind();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _retry();
  }

  Future<CommunityPost?> _readPost(CommunityAccountTicket ticket) async {
    ticket.check();
    final store = _repository!.communityPostStore;
    if (store is! CommunityPostLookupContract) {
      throw StateError('Public post lookup unavailable');
    }
    final posts = await (store as CommunityPostLookupContract).loadPostsByIds([
      widget.postId,
    ]);
    ticket.check();
    final post = posts.where((post) => post.id == widget.postId).singleOrNull;
    if (post == null ||
        post.moderationStatus != CommunityPostModerationStatus.approved ||
        post.moderationVisibility !=
            CommunityPostModerationVisibility.visible) {
      return null;
    }
    return post;
  }

  Future<_CommunityNotificationPost?> _load() async {
    final generation = ++_generation;
    final ticket = _visit?.capture();
    if (ticket == null ||
        !widget.validQuery ||
        !CommunityDeepLink.isContentId(widget.postId) ||
        (widget.commentId != null &&
            !CommunityDeepLink.isContentId(widget.commentId!))) {
      return null;
    }
    return ticket.run(() async {
      final post = await _readPost(ticket);
      if (post == null) return null;
      final stats = await _repository!.loadPostStats([post.id]);
      ticket.check();
      if (stats.length != 1 || stats.single.postId != post.id) return null;
      final latest = await _readPost(ticket);
      if (latest == null || generation != _generation) return null;
      return _CommunityNotificationPost(
        latest,
        stats.single,
        ticket,
        generation,
      );
    });
  }

  Future<bool> _verifyAccess(_CommunityNotificationPost loaded) async {
    if (!mounted ||
        loaded.generation != _generation ||
        !loaded.ticket.isCurrent) {
      return false;
    }
    try {
      final post = await loaded.ticket.run(() async {
        final candidate = await _readPost(loaded.ticket);
        if (candidate == null) return null;
        // Base post RLS and social visibility are distinct contracts. Stats
        // also enforce current block/audience access before any repaint.
        final stats = await _repository!.loadPostStats([candidate.id]);
        loaded.ticket.check();
        return stats.length == 1 && stats.single.postId == candidate.id
            ? candidate
            : null;
      });
      if (!mounted ||
          loaded.generation != _generation ||
          !loaded.ticket.isCurrent) {
        return false;
      }
      if (post != null) return true;
      setState(() => _accessRemoved = true);
      return false;
    } catch (error) {
      if (mounted &&
          loaded.generation == _generation &&
          loaded.ticket.isCurrent) {
        setState(() => _accessError = error);
      }
      return false;
    }
  }

  void _retry() {
    setState(() {
      _accessRemoved = false;
      _accessError = null;
      _loading = _load();
    });
  }

  Widget _unavailable(BuildContext context, {bool retry = false}) => Scaffold(
    appBar: AppBar(
      leading: const CommunityReturnButton(),
      title: Text(communityText(context, 'Post', 'منشور')),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              communityText(
                context,
                retry
                    ? 'Could not open this post. Try again.'
                    : 'This post is no longer available to this account.',
                retry
                    ? 'تعذر فتح المنشور. حاول مجددًا.'
                    : 'هذا المنشور لم يعد متاحًا لهذا الحساب.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              key: const Key('community-content-retry'),
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<_CommunityNotificationPost?>(
        key: ValueKey((_visit?.epoch, _generation)),
        future: _loading,
        builder: (context, snapshot) {
          if (_accessRemoved || _accessError != null) {
            return _unavailable(context, retry: _accessError != null);
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              appBar: AppBar(
                leading: const CommunityReturnButton(),
                title: Text(communityText(context, 'Post', 'منشور')),
              ),
              body: const Center(child: BilFeatureWelcomeStatus()),
            );
          }
          final loaded = snapshot.data;
          if (snapshot.hasError || loaded == null || !loaded.ticket.isCurrent) {
            return _unavailable(context, retry: snapshot.hasError);
          }
          return _CommunityPostDetailPage(
            key: ValueKey((loaded.generation, loaded.ticket.epoch)),
            post: loaded.post,
            initialStats: loaded.stats,
            repository: _repository!,
            ownerIsCurrent: () =>
                loaded.ticket.isCurrent &&
                loaded.generation == _generation &&
                !_accessRemoved &&
                _accessError == null,
            ownerChanges: _visit,
            focusCommentId: widget.commentId,
            notificationLoader: CommunityNotificationContentLoader(
              _repository!,
            ),
            verifyAccess: () => _verifyAccess(loaded),
          );
        },
      );
  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _visit?.dispose();
    super.dispose();
  }
}

class _CommunityNotificationPost {
  const _CommunityNotificationPost(
    this.post,
    this.stats,
    this.ticket,
    this.generation,
  );
  final CommunityPost post;
  final CommunityPostStats stats;
  final CommunityAccountTicket ticket;
  final int generation;
}
