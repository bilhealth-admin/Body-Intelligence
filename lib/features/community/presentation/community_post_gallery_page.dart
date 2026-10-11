import 'package:flutter/material.dart';

import '../domain/community_models.dart';
import 'community_copy.dart';
import 'community_return_button.dart';

/// Opens the exact ordered media of a post at the tapped thumbnail. The feed's
/// compact collage does not replace full-resolution, accessible gallery access.
class CommunityPostGalleryPage extends StatefulWidget {
  const CommunityPostGalleryPage({
    required this.media,
    this.initialIndex = 0,
    super.key,
  }) : assert(media.length > 0 && media.length <= 4),
       assert(initialIndex >= 0 && initialIndex < media.length);

  final List<CommunityPostMedia> media;
  final int initialIndex;

  @override
  State<CommunityPostGalleryPage> createState() =>
      _CommunityPostGalleryPageState();
}

class _CommunityPostGalleryPageState extends State<CommunityPostGalleryPage> {
  late final _media = List<CommunityPostMedia>.unmodifiable(widget.media);
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  late final _transforms = [for (final _ in _media) TransformationController()];
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    for (final transform in _transforms) {
      transform.addListener(_updateZoom);
    }
  }

  void _updateZoom() {
    final zoomed = _transforms[_index].value.getMaxScaleOnAxis() > 1.01;
    if (mounted && zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _select(int index) {
    if (index < 0 || index >= _media.length || index == _index) return;
    _transforms[_index].value = Matrix4.identity();
    _pages.jumpToPage(index);
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final transform in _transforms) {
      transform.removeListener(_updateZoom);
      transform.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Scaffold(
      key: const Key('community-full-post-gallery'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: const CommunityReturnButton(),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(communityText(context, 'Post photos', 'صور المنشور')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${_index + 1}/${_media.length}',
                key: const Key('community-gallery-position'),
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: const Key('community-full-gallery-pages'),
                controller: _pages,
                itemCount: _media.length,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                onPageChanged: (index) {
                  _transforms[_index].value = Matrix4.identity();
                  setState(() {
                    _index = index;
                    _zoomed = false;
                  });
                },
                itemBuilder: (context, index) => InteractiveViewer(
                  key: Key('community-gallery-viewer-$index'),
                  transformationController: _transforms[index],
                  minScale: 1,
                  maxScale: 4,
                  child: Center(child: _GalleryImage(item: _media[index])),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  key: const Key('community-gallery-previous'),
                  tooltip: material.previousPageTooltip,
                  onPressed: _index > 0 ? () => _select(_index - 1) : null,
                  icon: const BackButtonIcon(),
                  color: Colors.white,
                  disabledColor: Colors.white38,
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                ),
                IconButton(
                  key: const Key('community-gallery-next'),
                  tooltip: material.nextPageTooltip,
                  onPressed: _index + 1 < _media.length
                      ? () => _select(_index + 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  color: Colors.white,
                  disabledColor: Colors.white38,
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
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

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({required this.item});
  final CommunityPostMedia item;

  @override
  Widget build(BuildContext context) {
    Widget unavailable() => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          communityText(context, 'Photo unavailable', 'الصورة غير متاحة'),
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
    final url = item.url;
    if (url == null) return unavailable();
    final label = communityText(context, 'Post photo', 'صورة المنشور');
    return url.startsWith('asset://')
        ? Image.asset(
            url.substring('asset://'.length),
            fit: BoxFit.contain,
            semanticLabel: label,
            errorBuilder: (_, _, _) => unavailable(),
          )
        : Image.network(
            url,
            fit: BoxFit.contain,
            semanticLabel: label,
            errorBuilder: (_, _, _) => unavailable(),
          );
  }
}
