part of 'community_hub_page.dart';

extension _CommunityPostComposerToolbar on _CommunityPostComposerPageState {
  Widget buildCommunityPostComposerToolbar(
    BuildContext context,
    bool busy,
  ) => Material(
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
          if (_publishing && _selectedImages.isNotEmpty) ...[
            const LinearProgressIndicator(
              key: Key('community-post-upload-progress'),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('community-post-save-draft'),
                onPressed: busy
                    ? null
                    : _CommunityPostComposerReferenceActions(
                        this,
                      )._savePersistentDraft,
                icon: _savingDraft
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.drafts_outlined),
                label: Text(
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
              OutlinedButton.icon(
                key: const Key('community-post-add-photo'),
                onPressed: busy || _selectedImages.length >= 4
                    ? null
                    : _pickImage,
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
              ),
              FilledButton.icon(
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
        ],
      ),
    ),
  );
}
