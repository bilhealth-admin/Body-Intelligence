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
    // Preserve the publishing button's geometry, text, and surface while a
    // request is pending. The progress glyph occupies the same icon slot.
    final publishColor = dark
        ? const Color(0xFF285778)
        : const Color(0xFF17629E);
    final publish = Semantics(
      liveRegion: _publishing,
      label: _publishing
          ? communityText(context, 'Publishing…', 'جارٍ النشر…')
          : communityText(context, 'Publish', 'نشر'),
      child: FilledButton.icon(
        key: const Key('community-post-publish'),
        onPressed: busy ? null : _publish,
        style: FilledButton.styleFrom(
          backgroundColor: publishColor,
          disabledBackgroundColor: publishColor,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: SizedBox.square(
          dimension: 20,
          child: _publishing
              ? const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                )
              : const Icon(Icons.arrow_upward_rounded, size: 20),
        ),
        label: Text(
          communityText(context, 'Publish', 'نشر'),
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
            if (_selectedImages.isNotEmpty) ...[
              Visibility(
                visible: _publishing,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: const LinearProgressIndicator(
                  key: Key('community-post-upload-progress'),
                ),
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
                  const SizedBox(width: 10),
                  Expanded(flex: 59, child: publish),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
