part of 'community_post_moderation_page.dart';

class _HiddenPostCard extends StatelessWidget {
  const _HiddenPostCard({
    required this.post,
    required this.busy,
    required this.onRestore,
  });

  final CommunityPost post;
  final bool busy;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('community-hidden-post-${post.id}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            post.authorName ?? communityText(context, 'BIL member', 'عضو BIL'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Chip(
              avatar: const Icon(Icons.visibility_off_outlined, size: 18),
              label: Text(communityText(context, 'Hidden', 'مخفي')),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(post.body),
          if (post.mediaItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ModerationMediaGrid(post: post),
          ],
          if (post.poll != null) ...[
            const SizedBox(height: 12),
            _ModerationPollPreview(postId: post.id, poll: post.poll!),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              key: Key('community-hidden-post-restore-${post.id}'),
              onPressed: busy ? null : onRestore,
              icon: const Icon(Icons.restore_rounded),
              label: Text(
                communityText(context, 'Restore post', 'استعادة المنشور'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PendingPostCard extends StatelessWidget {
  const _PendingPostCard({
    required this.post,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final CommunityPost post;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('community-moderation-post-${post.id}'),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BilAccountAvatar(radius: 20, networkUrl: post.authorAvatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  post.authorName ??
                      communityText(context, 'BIL member', 'عضو BIL'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                MaterialLocalizations.of(
                  context,
                ).formatShortDate(post.createdAt.toLocal()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Chip(
              avatar: const Icon(Icons.pending_outlined, size: 18),
              label: Text(communityText(context, 'Pending', 'قيد المراجعة')),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            post.body,
            textDirection: BilWrittenLanguageResolver.directionFor(
              post.body,
              fallback: Directionality.of(context),
            ),
          ),
          if (post.mediaItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ModerationMediaGrid(post: post),
          ],
          if (post.poll != null) ...[
            const SizedBox(height: 12),
            _ModerationPollPreview(postId: post.id, poll: post.poll!),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: Key('community-moderation-approve-${post.id}'),
                onPressed: busy ? null : onApprove,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(communityText(context, 'Approve', 'اعتماد')),
              ),
              OutlinedButton.icon(
                key: Key('community-moderation-reject-${post.id}'),
                onPressed: busy ? null : onReject,
                icon: const Icon(Icons.cancel_outlined),
                label: Text(communityText(context, 'Reject', 'رفض')),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _OpenReportCard extends StatelessWidget {
  const _OpenReportCard({
    required this.report,
    required this.busy,
    required this.onClose,
    required this.onRemove,
  });

  final Map<String, dynamic> report;
  final bool busy;
  final VoidCallback onClose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final targetKind = report['target_kind']?.toString() ?? 'unknown';
    final canRemove = const {'post', 'message'}.contains(targetKind);
    return Card(
      key: Key('community-moderation-report-${report['id']}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$targetKind · ${report['target_id']}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip(
                avatar: const Icon(Icons.flag_outlined, size: 18),
                label: Text(
                  communityText(context, 'Open report', 'بلاغ مفتوح'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(report['reason']?.toString() ?? ''),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: busy ? null : onClose,
                  child: Text(
                    communityText(context, 'Close report', 'إغلاق البلاغ'),
                  ),
                ),
                if (canRemove)
                  OutlinedButton(
                    onPressed: busy ? null : onRemove,
                    child: Text(
                      communityText(
                        context,
                        'Remove reported content',
                        'إزالة المحتوى المُبلّغ عنه',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModerationMediaGrid extends StatelessWidget {
  const _ModerationMediaGrid({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final items = post.mediaItems.take(4).toList(growable: false);
    return GridView.builder(
      key: Key('community-moderation-media-${post.id}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: items.length == 1 ? 1 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ClipRRect(
          key: Key('community-moderation-media-${post.id}-$index'),
          borderRadius: BorderRadius.circular(14),
          child: item.url == null
              ? const ColoredBox(
                  color: Color(0xFFE8EBF0),
                  child: Icon(Icons.broken_image_outlined),
                )
              : Image.network(
                  item.url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFE8EBF0),
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
        );
      },
    );
  }
}

class _ModerationPollPreview extends StatelessWidget {
  const _ModerationPollPreview({required this.postId, required this.poll});

  final String postId;
  final CommunityPoll poll;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('community-moderation-poll-$postId'),
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            poll.question,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            poll.allowMultiple
                ? communityText(context, 'Multiple choice', 'اختيارات متعددة')
                : communityText(context, 'Single choice', 'اختيار واحد'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          for (final option in poll.options)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Text(option.text),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ModerationUnavailable extends StatelessWidget {
  const _ModerationUnavailable({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 56),
          const SizedBox(height: 14),
          Text(
            communityText(
              context,
              'Moderator access is required.',
              'يتطلب هذا القسم صلاحية مشرف.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            communityText(
              context,
              'The server verifies moderator access before returning any pending content.',
              'يتحقق الخادم من صلاحية المشرف قبل إرجاع أي محتوى معلّق.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
          ),
        ],
      ),
    ),
  );
}

class _CommunityModerationQueue {
  const _CommunityModerationQueue({
    required this.posts,
    required this.hiddenPosts,
    required this.reports,
  });

  final List<CommunityPost> posts;
  final List<CommunityPost> hiddenPosts;
  final List<Map<String, dynamic>> reports;
}
