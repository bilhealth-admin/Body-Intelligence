part of 'community_channels_page.dart';

extension _CommunityChannelsDirectory on _CommunityChannelsViewState {
  Widget _directory() {
    final blocking = _blockingState();
    if (blocking != null) return blocking;
    final controller = _controller;
    final channels = controller.channels
        .where((channel) => channel.canRead)
        .toList(growable: false);
    if (channels.isEmpty && controller.loadingDirectory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (channels.isEmpty) {
      return _empty(
        controller.directoryError == null
            ? CommunityChannelsCopyKey.directoryEmpty
            : CommunityChannelsCopyKey.directoryUnavailable,
        onRetry: () => _refresh(controller),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(controller),
      child: ListView(
        key: const Key('bil07-directory'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.directoryError != null)
            _notice(
              CommunityChannelsCopyKey.directoryUnavailable,
              action: TextButton.icon(
                onPressed: () => controller.loadDirectory(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_copy(CommunityChannelsCopyKey.retry)),
              ),
            ),
          for (final channel in channels)
            Card(
              key: ValueKey('bil07-channel-${channel.id}'),
              margin: const EdgeInsets.symmetric(vertical: 5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _open(controller, channel),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 23,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.forum_outlined,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channel.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (channel.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(channel.description),
                            ],
                            const SizedBox(height: 6),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary
                                    .withValues(
                                      alpha: (channel.unreadCount ?? 0) > 0
                                          ? .13
                                          : .035,
                                    ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                child: Text(
                                  _unreadLabel(channel.unreadCount),
                                  key: ValueKey(
                                    'bil07-channel-count-${channel.id}',
                                  ),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ),
                            if (!channel.canSend)
                              Text(_copy(CommunityChannelsCopyKey.readOnly)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const ExcludeSemantics(
                        // This Material icon already mirrors in RTL.
                        child: Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (controller.hasMoreChannels)
            TextButton.icon(
              key: const Key('bil07-load-more-channels'),
              onPressed: controller.loadingDirectory
                  ? null
                  : () => controller.loadDirectory(more: true),
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(_copy(CommunityChannelsCopyKey.loadMoreChannels)),
            ),
        ],
      ),
    );
  }
}
