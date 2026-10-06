part of 'community_hub_page.dart';

extension _CommunityDraftsPreview on _CommunityDraftsSheetState {
  Widget _previewTile(
    CommunityDraftSummary summary,
    AsyncSnapshot<_CommunityDraftMosaicPreview> snapshot,
    double width,
  ) {
    final preview = snapshot.data;
    final count = preview?.draft.media.length ?? summary.mediaCount;
    final images = preview?.images ?? const <CommunityPostImagePreview?>[];
    final scheme = Theme.of(context).colorScheme;
    final retry =
        snapshot.hasError ||
        (snapshot.connectionState == ConnectionState.done &&
            count > 0 &&
            (images.length < count || images.any((image) => image == null)));

    Widget cell(int index) {
      final image = index < images.length ? images[index] : null;
      return Semantics(
        label:
            '${communityText(context, 'Post photos', 'صور المنشور')} ${index + 1}/$count',
        image: true,
        child: image == null
            ? ColoredBox(
                key: Key(
                  'community-draft-photo-placeholder-${summary.draftId}-$index',
                ),
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_outlined,
                  size: 24,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : Image.memory(
                image.bytes,
                key: Key('community-draft-photo-${summary.draftId}-$index'),
                fit: BoxFit.cover,
                cacheWidth: 256,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
      );
    }

    Widget pair(Widget first, Widget second) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: first),
        const SizedBox(width: 2),
        Expanded(child: second),
      ],
    );

    Widget stacked(Widget first, Widget second) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: first),
        const SizedBox(height: 2),
        Expanded(child: second),
      ],
    );

    final mosaic = switch (count) {
      1 => cell(0),
      2 => stacked(cell(0), cell(1)),
      3 => pair(cell(0), stacked(cell(1), cell(2))),
      4 => stacked(pair(cell(0), cell(1)), pair(cell(2), cell(3))),
      _ => ColoredBox(
        color: scheme.surfaceContainerLow,
        child: Icon(Icons.edit_note_rounded, size: 34, color: scheme.primary),
      ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        key: Key('community-draft-mosaic-${summary.draftId}'),
        width: width,
        height: width * 87 / 70,
        child: Stack(
          fit: StackFit.expand,
          children: [
            mosaic,
            if (retry)
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: IconButton.filledTonal(
                  key: Key('community-draft-preview-retry-${summary.draftId}'),
                  tooltip: communityText(context, 'Retry', 'إعادة المحاولة'),
                  onPressed: () => _retryPreview(summary.draftId),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
