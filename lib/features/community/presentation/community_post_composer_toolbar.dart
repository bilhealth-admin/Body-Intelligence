part of 'community_hub_page.dart';

extension _CommunityPostComposerToolbar on _CommunityPostComposerPageState {
  Widget buildCommunityPostComposerToolbar(BuildContext context, bool busy) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final saveDraft = OutlinedButton.icon(
      key: const Key('community-post-save-draft'),
      onPressed: busy ? null : _savePersistentDraft,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        foregroundColor: dark
            ? const Color(0xFF93BEFF)
            : const Color(0xFF0866FF),
        side: BorderSide(
          color: dark ? const Color(0xFF365172) : const Color(0xFFDCE9FA),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: _savingDraft
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined, size: 19),
      label: Text(
        widget.draft.savedPersistently
            ? communityText(context, 'Update draft', 'تحديث المسودة')
            : communityText(context, 'Save draft', 'حفظ المسودة'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
    final publish = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: busy
              ? const [Color(0xFF719ED4), Color(0xFF4775B5)]
              : const [Color(0xFF278BFF), Color(0xFF0061FF)],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: busy
            ? null
            : const [
                BoxShadow(
                  color: Color(0x24136CFF),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: FilledButton.icon(
        key: const Key('community-post-publish'),
        onPressed: busy ? null : _publish,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 68),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: _publishing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.near_me_outlined, size: 25),
        label: Text(
          _publishing && _selectedImages.isNotEmpty
              ? communityText(context, 'Uploading photo…', 'جارٍ رفع الصورة…')
              : communityText(context, 'Publish', 'نشر'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
    return Material(
      color: dark ? CommunitySapphire.canvas(context) : const Color(0xFFFBFDFF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_submitError case final error?) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: const Key('community-post-submit-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_operationRecovery)
              TextButton(
                key: const Key('community-cancel-pending-publish'),
                onPressed: busy ? null : _cancelPendingPublish,
                child: Text(
                  communityText(
                    context,
                    'Cancel pending attempt',
                    'إلغاء المحاولة المعلّقة',
                  ),
                ),
              ),
            if (_publishing && _selectedImages.isNotEmpty) ...[
              const LinearProgressIndicator(
                key: Key('community-post-upload-progress'),
              ),
              const SizedBox(height: 8),
            ],
            if (scale >= 1.4 || MediaQuery.sizeOf(context).width < 350) ...[
              saveDraft,
              const SizedBox(height: 10),
              publish,
            ] else
              Row(
                key: const Key('community-composer-primary-actions'),
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(flex: 41, child: saveDraft),
                  const SizedBox(width: 24),
                  Expanded(flex: 59, child: publish),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
