part of 'community_hub_page.dart';

extension _CommunityPostComposerImages on _CommunityPostComposerPageState {
  Widget _buildCommunityImageStrip(
    BuildContext context,
    bool busy,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final width = ((constraints.maxWidth - 18) / 4).clamp(76.0, 92.0);
      final label = communityText(context, 'Add photos', 'إضافة صور');
      final labelStyle =
          (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
              .copyWith(fontSize: 10, fontWeight: FontWeight.w500, height: 1.2);
      final countStyle = labelStyle.copyWith(fontWeight: FontWeight.w400);
      double textHeight(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: width - 10);
        final result = painter.height;
        painter.dispose();
        return result;
      }

      // Keep a compact reference-style strip at ordinary type sizes, while
      // allowing every translated label to wrap at the user's text scale.
      final height =
          (45 +
                  textHeight(label, labelStyle) +
                  textHeight('${_selectedImages.length}/4', countStyle))
              .clamp(88.0, double.infinity);
      final dark = Theme.of(context).brightness == Brightness.dark;
      return SizedBox(
        height: height,
        child: ListView.separated(
          key: const Key('community-post-selected-images'),
          scrollDirection: Axis.horizontal,
          itemCount: _selectedImages.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            if (index < _selectedImages.length) {
              return _CommunityPostImagePreview(
                index: index,
                image: _selectedImages[index],
                width: width,
                height: height,
                onRemove: busy
                    ? null
                    : () => _setComposerState(() {
                        _selectedImages.removeAt(index);
                        widget.draft.images
                          ..clear()
                          ..addAll(_selectedImages);
                        _composerError = null;
                      }),
              );
            }
            return SizedBox(
              key: const Key('community-composer-media-tile'),
              width: width,
              height: height,
              child: OutlinedButton(
                key: const Key('community-post-add-photo'),
                onPressed: busy || _selectedImages.length >= 4
                    ? null
                    : _pickImage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 8,
                  ),
                  backgroundColor: dark
                      ? const Color(0xFF1B2A40)
                      : const Color(0xFFF3F8FF),
                  foregroundColor: dark
                      ? const Color(0xFF9AC2FF)
                      : const Color(0xFF0866FF),
                  disabledForegroundColor: CommunitySapphire.muted(context),
                  side: BorderSide(
                    color: dark
                        ? const Color(0xFF365172)
                        : const Color(0xFFDCE9FA),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _selectingImage
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded, size: 25),
                    const SizedBox(height: 4),
                    Text(label, textAlign: TextAlign.center, style: labelStyle),
                    const SizedBox(height: 2),
                    Text(
                      '${_selectedImages.length}/4',
                      textDirection: TextDirection.ltr,
                      style: countStyle,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _CommunityPostImagePreview extends StatelessWidget {
  const _CommunityPostImagePreview({
    required this.index,
    required this.image,
    required this.width,
    required this.height,
    this.onRemove,
  });

  final int index;
  final CommunityPostImageDraft image;
  final double width;
  final double height;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: communityText(context, 'Selected photo', 'الصورة المحددة'),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        key: Key('community-selected-photo-$index'),
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              image.bytes,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: IconButton(
                key: Key(
                  index == 0
                      ? 'community-post-remove-photo'
                      : 'community-post-remove-photo-$index',
                ),
                onPressed: onRemove,
                tooltip: communityText(context, 'Remove photo', 'إزالة الصورة'),
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
                icon: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xEFFFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: Color(0xFF23374E),
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
