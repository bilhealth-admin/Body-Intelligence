part of 'community_hub_page.dart';

extension _CommunityPostComposerToolbar on _CommunityPostComposerPageState {
  Widget buildCommunityPostComposerToolbar(BuildContext context, bool busy) {
    void reveal(GlobalKey anchor) {
      final target = anchor.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: .08,
      );
    }

    void revealPoll() {
      if (!widget.draft.pollEnabled) {
        _setComposerState(() => widget.draft.pollEnabled = true);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) reveal(_pollAnchor);
      });
    }

    final saveDraft = OutlinedButton.icon(
      key: const Key('community-post-save-draft'),
      onPressed: busy
          ? null
          : _CommunityPostComposerReferenceActions(this)._savePersistentDraft,
      icon: _savingDraft
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.drafts_outlined),
      label: Text(
        widget.draft.savedPersistently
            ? communityText(context, 'Update draft', 'تحديث المسودة')
            : communityText(context, 'Save draft', 'حفظ المسودة'),
      ),
    );
    final addPhoto = OutlinedButton.icon(
      key: const Key('community-post-add-photo'),
      onPressed: busy || _selectedImages.length >= 4 ? null : _pickImage,
      icon: _selectingImage
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_photo_alternate_outlined),
      label: Text(
        communityText(
          context,
          _selectedImages.isEmpty
              ? 'Add photo'
              : 'Add photo (${_selectedImages.length}/4)',
          _selectedImages.isEmpty
              ? 'إضافة صورة'
              : 'إضافة صورة (${_selectedImages.length}/4)',
        ),
      ),
    );
    final publish = FilledButton.icon(
      key: const Key('community-post-publish'),
      onPressed: busy ? null : _publish,
      icon: _publishing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_rounded),
      label: Text(
        _publishing && _selectedImages.isNotEmpty
            ? communityText(context, 'Uploading photo…', 'جارٍ رفع الصورة…')
            : communityText(context, 'Publish', 'نشر'),
      ),
    );

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_submitError case final error?) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: const Key('community-post-submit-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            if (_publishing && _selectedImages.isNotEmpty) ...[
              const LinearProgressIndicator(
                key: Key('community-post-upload-progress'),
              ),
              const SizedBox(height: 8),
            ],
            SingleChildScrollView(
              key: const Key('community-composer-reference-action-rail'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton.icon(
                    key: const Key('community-composer-action-location'),
                    onPressed: busy ? null : () => reveal(_locationAnchor),
                    icon: const Icon(Icons.location_on_outlined, size: 19),
                    label: Text(communityText(context, 'Location', 'الموقع')),
                  ),
                  TextButton.icon(
                    key: const Key('community-composer-action-poll'),
                    onPressed: busy ? null : revealPoll,
                    icon: const Icon(Icons.poll_outlined, size: 19),
                    label: Text(communityText(context, 'Poll', 'استطلاع')),
                  ),
                  TextButton.icon(
                    key: const Key('community-composer-action-circle'),
                    onPressed: busy ? null : () => reveal(_circleAnchor),
                    icon: const Icon(Icons.groups_2_outlined, size: 19),
                    label: Text(communityText(context, 'Circle', 'الدائرة')),
                  ),
                  TextButton.icon(
                    key: const Key('community-composer-action-collab'),
                    onPressed: busy ? null : () => reveal(_collaborationAnchor),
                    icon: const Icon(Icons.group_add_outlined, size: 19),
                    label: Text(communityText(context, 'Collab', 'تعاون')),
                  ),
                  PopupMenuButton<String>(
                    key: const Key('community-composer-action-more'),
                    enabled: !busy,
                    tooltip: communityText(context, 'More', 'المزيد'),
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) {
                      if (value == 'draft') {
                        _CommunityPostComposerReferenceActions(
                          this,
                        )._savePersistentDraft();
                      } else if (value == 'photo') {
                        _pickImage();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'draft',
                        child: Text(
                          widget.draft.savedPersistently
                              ? communityText(
                                  context,
                                  'Update draft',
                                  'تحديث المسودة',
                                )
                              : communityText(
                                  context,
                                  'Save draft',
                                  'حفظ المسودة',
                                ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'photo',
                        enabled: _selectedImages.length < 4,
                        child: Text(
                          communityText(context, 'Add photo', 'إضافة صورة'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final stacked = constraints.maxWidth < 420 || textScale >= 1.4;
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      saveDraft,
                      const SizedBox(height: 8),
                      addPhoto,
                      const SizedBox(height: 8),
                      publish,
                    ],
                  );
                }
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [saveDraft, addPhoto, publish],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
