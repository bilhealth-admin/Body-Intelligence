part of 'community_hub_page.dart';

class _CommunityAuthorRelationshipAction extends StatefulWidget {
  const _CommunityAuthorRelationshipAction({
    required this.post,
    required this.repository,
    required this.enabled,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final bool enabled;

  @override
  State<_CommunityAuthorRelationshipAction> createState() =>
      _CommunityAuthorRelationshipActionState();
}

class _CommunityAuthorRelationshipActionState
    extends State<_CommunityAuthorRelationshipAction> {
  late CommunityRelationshipStatus? _relationship =
      widget.post.authorRelationship;
  late bool _canRequest = widget.post.authorCanRequest;
  bool _busy = false;

  Future<void> _request() async {
    if (_busy || !_canRequest || !widget.enabled) return;
    setState(() => _busy = true);
    try {
      final result = await widget.repository.requestFriend(
        widget.post.authorId,
      );
      if (!mounted) return;
      setState(() {
        _relationship = switch (result) {
          CommunityFriendRequestStatus.pending =>
            CommunityRelationshipStatus.pending,
          CommunityFriendRequestStatus.incoming =>
            CommunityRelationshipStatus.incoming,
          CommunityFriendRequestStatus.accepted =>
            CommunityRelationshipStatus.accepted,
          CommunityFriendRequestStatus.declined =>
            CommunityRelationshipStatus.none,
        };
        _canRequest = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Friend request could not be sent. Try again.',
              'تعذر إرسال طلب الصداقة. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_relationship == null) return const SizedBox.shrink();
    if (_relationship == CommunityRelationshipStatus.none && _canRequest) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: Key('community-post-add-friend-${widget.post.id}'),
          onPressed: widget.enabled && !_busy ? _request : null,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1_rounded, size: 17),
          label: Text(communityText(context, 'Add Friend', 'إضافة صديق')),
        ),
      );
    }
    final (icon, english, arabic) = switch (_relationship!) {
      CommunityRelationshipStatus.pending => (
        Icons.schedule_rounded,
        'Request pending',
        'الطلب قيد الانتظار',
      ),
      CommunityRelationshipStatus.incoming => (
        Icons.mark_email_unread_outlined,
        'Sent you a request',
        'أرسل إليك طلبًا',
      ),
      CommunityRelationshipStatus.accepted => (
        Icons.people_rounded,
        'Friend',
        'صديق',
      ),
      CommunityRelationshipStatus.self => (Icons.person_rounded, 'You', 'أنت'),
      CommunityRelationshipStatus.none => (
        Icons.person_off_outlined,
        'Unavailable',
        'غير متاح',
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            communityText(context, english, arabic),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _ExpandableCommunityPostBody extends StatefulWidget {
  const _ExpandableCommunityPostBody({
    required this.postId,
    required this.body,
  });

  final String postId;
  final String body;

  @override
  State<_ExpandableCommunityPostBody> createState() =>
      _ExpandableCommunityPostBodyState();
}

class _ExpandableCommunityPostBodyState
    extends State<_ExpandableCommunityPostBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final canCollapse =
        widget.body.length > 240 || '\n'.allMatches(widget.body).length >= 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          widget.body,
          key: ValueKey('community-post-body-${widget.postId}'),
          textDirection: BilWrittenLanguageResolver.directionFor(
            widget.body,
            fallback: Directionality.of(context),
          ),
          maxLines: canCollapse && !_expanded ? 4 : null,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (canCollapse)
          TextButton(
            key: ValueKey('community-post-expand-${widget.postId}'),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded
                  ? communityText(context, 'Show less', 'عرض أقل')
                  : communityText(context, 'Show more', 'عرض المزيد'),
            ),
          ),
      ],
    );
  }
}

class _CommunityPostStatusChip extends StatelessWidget {
  const _CommunityPostStatusChip({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final (icon, english, arabic) = switch (post.moderationStatus) {
      CommunityPostModerationStatus.pending => (
        Icons.schedule_rounded,
        'Pending review',
        'بانتظار المراجعة',
      ),
      CommunityPostModerationStatus.approved => (
        Icons.verified_outlined,
        'Approved',
        'معتمد',
      ),
      CommunityPostModerationStatus.rejected => (
        Icons.cancel_outlined,
        'Rejected',
        'مرفوض',
      ),
    };
    final localizedStatus = communityText(context, english, arabic);
    final statusLabel = communityText(
      context,
      'Post status: {status}',
      'حالة المنشور: {status}',
    ).replaceAll('{status}', localizedStatus);
    return Semantics(
      label: statusLabel,
      child: Chip(
        key: Key('community-post-status-${post.id}'),
        avatar: Icon(icon, size: 16),
        visualDensity: VisualDensity.compact,
        label: Text(localizedStatus),
      ),
    );
  }
}

class _CommunityFeedImage extends StatelessWidget {
  const _CommunityFeedImage({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final media = post.mediaItems;
    if (media.isEmpty) return const SizedBox.shrink();
    if (media.length == 1) {
      final item = media.single;
      return Semantics(
        image: true,
        label: communityText(context, 'Post photo', 'صورة المنشور'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            key: Key('community-post-image-${post.id}'),
            aspectRatio: item.aspectRatio.clamp(.9, 1.91).toDouble(),
            child: _CommunityPostMediaTile(item: item),
          ),
        ),
      );
    }
    final visible = media.take(4).toList(growable: false);
    return Semantics(
      image: true,
      label: communityText(context, 'Post photos', 'صور المنشور'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          key: Key('community-post-image-${post.id}'),
          aspectRatio: 2.02,
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _CommunityPostMediaTile(item: visible[0]),
                        ),
                        if (visible.length > 2) ...[
                          const SizedBox(height: 3),
                          Expanded(
                            child: _CommunityPostMediaTile(item: visible[2]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _CommunityPostMediaTile(item: visible[1]),
                        ),
                        if (visible.length > 3) ...[
                          const SizedBox(height: 3),
                          Expanded(
                            child: _CommunityPostMediaTile(item: visible[3]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              PositionedDirectional(
                top: 8,
                end: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    child: Text(
                      '${visible.length}/${media.length}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              if (media.length > 4)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .68),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+${media.length - 4}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityPostMediaTile extends StatelessWidget {
  const _CommunityPostMediaTile({required this.item});

  final CommunityPostMedia item;

  @override
  Widget build(BuildContext context) {
    final url = item.url;
    if (url == null) return const _CommunityImageFallback();
    final image = url.startsWith('asset://')
        ? Image.asset(
            url.substring('asset://'.length),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const _CommunityImageFallback(),
          )
        : Image.network(
            url,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const _CommunityImageFallback(),
          );
    return InkWell(
      onTap: () => pushCommunityPage<void>(
        context,
        _CommunityPhotoPage(url: url),
      ),
      child: image,
    );
  }
}

class _CommunityPhotoPage extends StatelessWidget {
  const _CommunityPhotoPage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      titleTextStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: Colors.white),
      title: Text(communityText(context, 'Post photo', 'صورة المنشور')),
    ),
    body: SafeArea(
      child: InteractiveViewer(
        key: const Key('community-photo-viewer'),
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: url.startsWith('asset://')
              ? Image.asset(
                  url.substring('asset://'.length),
                  fit: BoxFit.contain,
                  semanticLabel: communityText(
                    context,
                    'Post photo',
                    'صورة المنشور',
                  ),
                  errorBuilder: (_, _, _) => const _CommunityImageFallback(),
                )
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  semanticLabel: communityText(
                    context,
                    'Post photo',
                    'صورة المنشور',
                  ),
                  errorBuilder: (_, _, _) => const _CommunityImageFallback(),
                ),
        ),
      ),
    ),
  );
}

class _CommunityImageFallback extends StatelessWidget {
  const _CommunityImageFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined),
            const SizedBox(height: 6),
            Text(
              communityText(context, 'Photo unavailable', 'الصورة غير متاحة'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
