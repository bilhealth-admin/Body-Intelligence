part of 'community_hub_page.dart';

class _CommunityPostImagePreview extends StatelessWidget {
  const _CommunityPostImagePreview({
    required this.index,
    required this.image,
    this.onRemove,
  });

  final int index;
  final CommunityPostImageDraft image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: communityText(context, 'Selected photo', 'الصورة المحددة'),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 220,
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              image.bytes,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFE8EBF0),
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
            PositionedDirectional(
              top: 8,
              end: 8,
              child: IconButton.filledTonal(
                key: Key(
                  index == 0
                      ? 'community-post-remove-photo'
                      : 'community-post-remove-photo-$index',
                ),
                onPressed: onRemove,
                tooltip: communityText(context, 'Remove photo', 'إزالة الصورة'),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
