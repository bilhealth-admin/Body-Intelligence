part of 'community_hub_page.dart';

class _FeedTab extends StatefulWidget {
  const _FeedTab({required this.repository, required this.imagePicker});
  final CommunityRepository repository;
  final CommunityPostImagePickerContract imagePicker;

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  final _composer = TextEditingController();
  late Future<List<CommunityPost>> _feed = widget.repository.loadFeed();
  bool _publishing = false;
  bool _managingPost = false;
  bool _selectingImage = false;
  CommunityPostImageDraft? _selectedImage;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_publishing || _managingPost || _selectingImage) return;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    setState(() => _publishing = true);
    try {
      final image = _selectedImage;
      if (image == null) {
        await widget.repository.publishPost(text);
      } else {
        await widget.repository.publishPostWithImage(text, image);
      }
      final refreshedFeed = widget.repository.loadFeed();
      _composer.clear();
      if (mounted) {
        setState(() {
          _selectedImage = null;
          _feed = refreshedFeed;
        });
      }
    } on CommunityTextPolicyException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.localizedMessage(
              Localizations.localeOf(context).toLanguageTag(),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              _selectedImage == null
                  ? 'Could not publish now. Your text is kept so you can retry.'
                  : 'Could not publish now. Your text and photo are kept so you can retry.',
              _selectedImage == null
                  ? 'تعذر نشر المشاركة الآن. احتفظنا بالنص لتعيد المحاولة.'
                  : 'تعذر النشر الآن. احتفظنا بالنص والصورة لتعيد المحاولة.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _pickImage() async {
    if (_publishing || _managingPost || _selectingImage) return;
    setState(() => _selectingImage = true);
    try {
      final image = await widget.imagePicker.pick();
      if (image != null && mounted) {
        setState(() => _selectedImage = image);
      }
    } on CommunityPostImageException catch (error) {
      if (!mounted) return;
      final (english, arabic) = switch (error.failure) {
        CommunityPostImageFailure.tooLarge => (
          'Photo too large. Choose an image up to 5 MB.',
          'الصورة كبيرة جدًا. اختر صورة بحجم لا يتجاوز 5 ميجابايت.',
        ),
        CommunityPostImageFailure.unsupportedType => (
          'Choose a JPEG, PNG, or WebP image.',
          'اختر صورة بصيغة JPEG أو PNG أو WebP.',
        ),
        CommunityPostImageFailure.invalidImage ||
        CommunityPostImageFailure.invalidDimensions => (
          'This photo could not be opened safely. Choose another photo.',
          'تعذر فتح هذه الصورة بأمان. اختر صورة أخرى.',
        ),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(communityText(context, english, arabic))),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Photo picker could not open. Try again.',
              'تعذر فتح اختيار الصور. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _selectingImage = false);
    }
  }

  Future<void> _managePost(CommunityPost post, String action) async {
    if (_publishing || _managingPost) return;
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(communityText(context, 'Delete post?', 'حذف المشاركة؟')),
          content: Text(
            communityText(
              context,
              'This removes your post from Community.',
              'سيؤدي ذلك إلى إزالة مشاركتك من المجتمع.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(communityText(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(communityText(context, 'Delete', 'حذف')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _managingPost = true);
    try {
      if (action == 'report') {
        await widget.repository.report(
          targetKind: 'post',
          targetId: post.id,
          reason: 'user_reported_from_feed',
        );
      } else if (action == 'delete') {
        await widget.repository.deletePost(post.id);
        final refreshedFeed = widget.repository.loadFeed();
        if (mounted) {
          setState(() {
            _feed = refreshedFeed;
          });
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'report'
                ? communityText(
                    context,
                    'Report sent for review.',
                    'تم إرسال البلاغ للمراجعة.',
                  )
                : communityText(context, 'Post deleted.', 'تم حذف المشاركة.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not complete that action safely. Try again.',
              'تعذر تنفيذ الإجراء بأمان. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _managingPost = false);
    }
  }

  Future<void> _refresh() async {
    if (_publishing || _managingPost) return;
    final refreshedFeed = widget.repository.loadFeed();
    setState(() {
      _feed = refreshedFeed;
    });
    await refreshedFeed;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: OutlinedButton.icon(
          key: const Key('community-browse-topics'),
          onPressed: _publishing || _managingPost
              ? null
              : () => CommunityTaxonomySheet.show(
                  context,
                  onSelectTag: (tag) {
                    _composer.text = '#$tag ';
                    _composer.selection = TextSelection.collapsed(
                      offset: _composer.text.length,
                    );
                  },
                ),
          icon: const Icon(Icons.grid_view_rounded),
          label: Text(CommunityTaxonomySheet.browseLabel(context)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('community-post-composer'),
              controller: _composer,
              enabled: !_publishing && !_managingPost,
              maxLength: 1200,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: communityText(
                  context,
                  'Share an experience or win',
                  'شارك تجربة أو إنجازًا',
                ),
                helperText: communityText(
                  context,
                  'Do not share private health data you want to keep private.',
                  'لا تشارك بيانات صحية خاصة لا تريد ظهورها.',
                ),
                helperMaxLines: 2,
              ),
            ),
            if (_selectedImage case final image?) ...[
              const SizedBox(height: 10),
              _CommunityPostImagePreview(
                image: image,
                onRemove: _publishing
                    ? null
                    : () => setState(() => _selectedImage = null),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runAlignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('community-post-add-photo'),
                  onPressed: _publishing || _managingPost || _selectingImage
                      ? null
                      : _pickImage,
                  icon: _selectingImage
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    communityText(context, 'Add photo', 'إضافة صورة'),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('community-post-publish'),
                  onPressed: _publishing || _managingPost || _selectingImage
                      ? null
                      : _publish,
                  icon: _publishing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _publishing && _selectedImage != null
                        ? communityText(
                            context,
                            'Uploading photo…',
                            'جارٍ رفع الصورة…',
                          )
                        : communityText(context, 'Publish', 'نشر'),
                  ),
                ),
              ],
            ),
            if (_publishing && _selectedImage != null) ...[
              const SizedBox(height: 6),
              const LinearProgressIndicator(
                key: Key('community-post-upload-progress'),
              ),
            ],
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<CommunityPost>>(
          future: _feed,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _InlineError(onRetry: _refresh);
            }
            final posts = snapshot.data ?? const [];
            if (posts.isEmpty) {
              return Center(
                child: Text(
                  communityText(
                    context,
                    'No posts yet. Start the first conversation.',
                    'لا توجد مشاركات بعد. ابدأ بأول مشاركة.',
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _CommunityPostCard(
                    post: post,
                    currentUserId: widget.repository.currentUserId,
                    actionsEnabled: !_publishing && !_managingPost,
                    onAction: (value) => _managePost(post, value),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _CommunityPostImagePreview extends StatelessWidget {
  const _CommunityPostImagePreview({required this.image, this.onRemove});

  final CommunityPostImageDraft image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: communityText(context, 'Selected photo', 'الصورة المحددة'),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
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
                key: const Key('community-post-remove-photo'),
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

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.currentUserId,
    required this.actionsEnabled,
    required this.onAction,
  });

  final CommunityPost post;
  final String currentUserId;
  final bool actionsEnabled;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BilAccountAvatar(radius: 20, networkUrl: post.authorAvatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NaturalCommunityText(
                      post.authorName ??
                          communityText(context, 'BIL member', 'عضو BIL'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatShortDate(post.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('community-post-actions-${post.id}'),
                enabled: actionsEnabled,
                onSelected: onAction,
                itemBuilder: (_) => post.authorId == currentUserId
                    ? [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(communityText(context, 'Delete', 'حذف')),
                        ),
                      ]
                    : [
                        PopupMenuItem(
                          value: 'report',
                          child: Text(
                            communityText(context, 'Report', 'إبلاغ'),
                          ),
                        ),
                      ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _NaturalCommunityText(post.body),
          if (post.hasImage) ...[
            const SizedBox(height: 12),
            _CommunityFeedImage(post: post),
          ],
        ],
      ),
    ),
  );
}

class _CommunityFeedImage extends StatelessWidget {
  const _CommunityFeedImage({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final ratio = (post.mediaAspectRatio ?? 1).clamp(0.8, 1.91).toDouble();
    final url = post.mediaUrl;
    return Semantics(
      image: true,
      label: communityText(context, 'Post photo', 'صورة المنشور'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          key: Key('community-post-image-${post.id}'),
          aspectRatio: ratio,
          child: url == null
              ? const _CommunityImageFallback()
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const _CommunityImageFallback(),
                ),
        ),
      ),
    );
  }
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
