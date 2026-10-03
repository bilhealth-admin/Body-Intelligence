part of 'community_profile_page.dart';

extension _CommunityProfileCoverActions on _CommunityProfilePageState {
  Future<void> pickCover() async {
    final repository = _repository;
    if (repository == null ||
        !repository.useServerCommunityReferenceParity ||
        _coverBusy ||
        _saving) {
      return;
    }
    setState(() => _coverBusy = true);
    try {
      final image = await CommunityPostImagePicker().pick();
      if (image == null || !mounted) return;
      final url = await repository.uploadMyCommunityProfileCover(image);
      if (!mounted) return;
      setState(() => _coverUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Profile cover updated.',
              'تم تحديث غلاف الملف.',
            ),
          ),
        ),
      );
    } on CommunityPostImageException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Choose a valid JPEG, PNG, or WebP image up to 5 MB.',
              'اختر صورة JPEG أو PNG أو WebP صالحة بحجم لا يتجاوز 5 ميجابايت.',
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
              'Could not update the profile cover.',
              'تعذر تحديث غلاف الملف.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _coverBusy = false);
    }
  }

  Future<void> removeCover() async {
    final repository = _repository;
    if (repository == null ||
        !repository.useServerCommunityReferenceParity ||
        _coverUrl == null ||
        _coverBusy ||
        _saving) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          communityText(
            context,
            'Remove profile cover?',
            'إزالة غلاف الملف؟',
          ),
        ),
        content: Text(
          communityText(
            context,
            'BIL will return to the branded Community cover.',
            'سيعود BIL إلى غلاف المجتمع الافتراضي.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(communityText(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(communityText(context, 'Remove', 'إزالة')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _coverBusy = true);
    try {
      await repository.removeMyCommunityProfileCover();
      if (mounted) setState(() => _coverUrl = null);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not remove the profile cover.',
              'تعذر إزالة غلاف الملف.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _coverBusy = false);
    }
  }
}

class _CommunityProfileCoverEditor extends StatelessWidget {
  const _CommunityProfileCoverEditor({
    required this.coverUrl,
    required this.busy,
    required this.saving,
    required this.onChange,
    required this.onRemove,
  });

  final String? coverUrl;
  final bool busy;
  final bool saving;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('community-profile-cover-editor'),
    clipBehavior: Clip.antiAlias,
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl != null)
                Image.network(
                  coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(context),
                )
              else
                _fallback(context),
              if (busy)
                const ColoredBox(
                  color: Colors.black26,
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const Key('community-profile-cover-change'),
                onPressed: busy || saving ? null : onChange,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  communityText(
                    context,
                    coverUrl == null ? 'Add cover' : 'Change cover',
                    coverUrl == null ? 'إضافة غلاف' : 'تغيير الغلاف',
                  ),
                ),
              ),
              if (coverUrl != null)
                TextButton.icon(
                  key: const Key('community-profile-cover-remove'),
                  onPressed: busy || saving ? null : onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    communityText(context, 'Remove', 'إزالة'),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _fallback(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primaryContainer,
        ],
      ),
    ),
    child: const Center(
      child: Icon(
        Icons.public_rounded,
        size: 58,
        color: Colors.white54,
      ),
    ),
  );
}
