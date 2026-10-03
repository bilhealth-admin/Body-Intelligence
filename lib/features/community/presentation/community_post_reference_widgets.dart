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

  String _collaboratorLabel(
    BuildContext context,
    CommunityPostCollaborator collaborator,
  ) {
    final identity = collaborator.handle?.isNotEmpty == true
        ? '@${collaborator.handle!}'
        : collaborator.displayName;
    final status = switch (collaborator.status) {
      CommunityCollaborationStatus.accepted => '',
      CommunityCollaborationStatus.pending =>
        ' · ${communityText(context, 'Pending', 'قيد الانتظار')}',
      CommunityCollaborationStatus.declined =>
        ' · ${communityText(context, 'Declined', 'مرفوض')}',
    };
    return '$identity$status';
  }

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
                ? Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
                : Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
                  label: Text(_collaboratorLabel(context, collaborator)),
                  side:
                      collaborator.status ==
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
                  '#$hashtag',
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
