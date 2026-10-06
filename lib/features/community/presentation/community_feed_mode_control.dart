part of 'community_hub_page.dart';

String _communityFeedModeLabel(BuildContext context, CommunityFeedMode mode) =>
    switch (mode) {
      CommunityFeedMode.explore => communityText(context, 'Explore', 'استكشاف'),
      CommunityFeedMode.following => communityText(
        context,
        'Following',
        'المتابَعون',
      ),
      CommunityFeedMode.friends => communityText(
        context,
        'Friends',
        'الأصدقاء',
      ),
      CommunityFeedMode.forYou => communityText(context, 'For You', 'لك'),
    };

/// Keep all authoritative feed modes in the existing actions sheet. The
/// landing page's Explore/Following/Circles row owns its visible navigation.
class _CommunityFeedModeControl extends StatelessWidget {
  const _CommunityFeedModeControl({required this.selectedMode});

  final CommunityFeedMode selectedMode;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: PopupMenuButton<CommunityFeedMode>(
      key: const Key('community-feed-mode-menu'),
      tooltip: _communityFeedModeLabel(context, selectedMode),
      initialValue: selectedMode,
      onSelected: (mode) =>
          Navigator.pop(context, 'feed-mode:${mode.wireValue}'),
      itemBuilder: (_) => [
        for (final mode in CommunityFeedMode.values)
          CheckedPopupMenuItem<CommunityFeedMode>(
            key: Key('community-feed-mode-${mode.wireValue}'),
            value: mode,
            checked: selectedMode == mode,
            child: Text(_communityFeedModeLabel(context, mode)),
          ),
      ],
      child: ListTile(
        minTileHeight: 60,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 4, 16, 4),
        leading: const Icon(Icons.tune_rounded),
        title: Text(_communityFeedModeLabel(context, selectedMode)),
        trailing: const Icon(Icons.expand_more_rounded),
      ),
    ),
  );
}
