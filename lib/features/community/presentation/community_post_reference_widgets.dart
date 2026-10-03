part of 'community_hub_page.dart';

class _CommunityPostReferenceBlock extends StatelessWidget {
  const _CommunityPostReferenceBlock({
    required this.metadata,
    required this.repository,
    this.compact = false,
  });

  final CommunityPostReferenceMetadata metadata;
  final CommunityRepository repository;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = metadata.title?.trim();
    final collaborators = metadata.collaborators;
    if (title?.isNotEmpty != true &&
        metadata.hashtags.isEmpty &&
        metadata.topics.isEmpty &&
        metadata.circle == null &&
        collaborators.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title?.isNotEmpty == true) ...[
          Text(
            title!,
            key: const Key('community-post-reference-title'),
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: compact
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  )
                : Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
          ),
          const SizedBox(height: 8),
        ],
        if (collaborators.isNotEmpty) ...[
          Wrap(
            key: const Key('community-post-collaborators'),
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                communityText(context, 'With', 'بالتعاون مع'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              for (final collaborator in collaborators)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: BilAccountAvatar(
                    radius: 10,
                    networkUrl: collaborator.avatarUrl,
                  ),
                  label: Text(
                    (collaborator.handle?.isNotEmpty == true
                            ? '@' + collaborator.handle!
                            : collaborator.displayName) +
                        switch (collaborator.status) {
                          CommunityCollaborationStatus.accepted => '',
                          CommunityCollaborationStatus.pending =>
                            ' · ' +
                                communityText(
                                  context,
                                  'Pending',
                                  'قيد الانتظار',
                                ),
                          CommunityCollaborationStatus.declined =>
                            ' · ' +
                                communityText(
                                  context,
                                  'Declined',
                                  'مرفوض',
                                ),
                        },
                  ),
                  side: collaborator.status ==
                          CommunityCollaborationStatus.accepted
                      ? null
                      : BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (metadata.topics.isNotEmpty || metadata.circle != null) ...[
          _CommunityPostTaxonomyReference(
            metadata: metadata,
            repository: repository,
          ),
          const SizedBox(height: 8),
        ],
        if (metadata.hashtags.isNotEmpty)
          Wrap(
            key: const Key('community-post-hashtags'),
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final hashtag in metadata.hashtags)
                Text(
                  '#' + hashtag,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}


class _CommunityPostTaxonomyReference extends StatelessWidget {
  const _CommunityPostTaxonomyReference({
    required this.metadata,
    required this.repository,
  });

  final CommunityPostReferenceMetadata metadata;
  final CommunityRepository repository;

  Future<void> _openTopic(
    BuildContext context,
    CommunityPostTopicReference reference,
  ) async {
    final topics = await repository.loadCommunityTopics();
    final topic = topics.where((value) => value.slug == reference.slug).firstOrNull;
    if (topic == null || !context.mounted) return;
    await pushCommunityPage<void>(
      context,
      _CommunityTopicPage(
        repository: repository,
        topic: topic,
      ),
    );
  }

  Future<void> _openCircle(
    BuildContext context,
    CommunityPostCircleReference reference,
  ) async {
    final circles = await repository.loadCommunityCircles();
    final circle = circles.where((value) => value.slug == reference.slug).firstOrNull;
    if (circle == null || !context.mounted) return;
    await pushCommunityPage<void>(
      context,
      _CommunityCirclePage(
        repository: repository,
        circle: circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final topic in metadata.topics)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          elevation: 0,
          child: ListTile(
            key: Key('community-post-topic-' + topic.slug),
            dense: true,
            leading: const Icon(Icons.tag_rounded),
            title: Text(
              CommunityTaxonomySheet.titleForSlug(context, topic.slug),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  communityText(
                    context,
                    topic.postCount.toString() + ' posts',
                    topic.postCount.toString() + ' منشور',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 6),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
              ],
            ),
            onTap: () => _openTopic(context, topic),
          ),
        ),
      if (metadata.circle case final circle?)
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          child: ListTile(
            key: Key('community-post-circle-' + circle.slug),
            dense: true,
            leading: const Icon(Icons.groups_outlined),
            title: Text(_circleTitle(context, circle.slug)),
            subtitle: Text(
              communityText(
                context,
                circle.memberCount.toString() +
                    ' members · ' +
                    circle.postCount.toString() +
                    ' posts',
                circle.memberCount.toString() +
                    ' عضو · ' +
                    circle.postCount.toString() +
                    ' منشور',
              ),
            ),
            trailing: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
            ),
            onTap: () => _openCircle(context, circle),
          ),
        ),
    ],
  );
}
