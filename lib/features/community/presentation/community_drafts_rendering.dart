part of 'community_hub_page.dart';

extension _CommunityDraftsRendering on _CommunityDraftsSheetState {
  String _savedLabel(DateTime updatedAt) {
    final now = DateTime.now().toUtc();
    final value = updatedAt.toUtc();
    final delta = now.isBefore(value) ? Duration.zero : now.difference(value);
    if (delta.inMinutes < 1) {
      return communityText(context, 'Saved just now', 'حُفظت الآن');
    }
    if (delta.inHours < 1) {
      return communityText(
        context,
        'Last saved {count}m ago',
        'آخر حفظ قبل {count} د',
      ).replaceAll('{count}', '${delta.inMinutes}');
    }
    if (delta.inDays < 1) {
      return communityText(
        context,
        'Last saved {count}h ago',
        'آخر حفظ قبل {count} س',
      ).replaceAll('{count}', '${delta.inHours}');
    }
    return communityText(
      context,
      'Last saved {count}d ago',
      'آخر حفظ قبل {count} ي',
    ).replaceAll('{count}', '${delta.inDays}');
  }

  List<String> _metadata(
    CommunityDraftSummary summary,
    CommunityPersistentDraft? draft,
  ) {
    final values = <String>[];
    if (summary.mediaCount > 0) {
      values.add(
        communityText(
          context,
          '{count} photos',
          '{count} صور',
        ).replaceAll('{count}', '${summary.mediaCount}'),
      );
    }
    if (draft?.pollQuestion?.trim().isNotEmpty == true) {
      values.add(communityText(context, 'Poll', 'استطلاع'));
    }
    if (draft?.topicSlugs.isNotEmpty == true) {
      values.add(
        CommunityTaxonomySheet.titleForSlug(context, draft!.topicSlugs.first),
      );
    } else if (draft?.circleSlug != null) {
      values.add(communityText(context, 'Circle', 'دائرة'));
    }
    return values;
  }

  Widget _previewTile(
    CommunityDraftSummary summary,
    AsyncSnapshot<
      ({CommunityPersistentDraft draft, CommunityPostImageDraft? image})
    >
    snapshot,
  ) {
    final image = snapshot.data?.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 112,
        height: 94,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              Image.memory(
                image.bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            else
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE9F3FF), Color(0xFFF3F8FD)],
                  ),
                ),
                child: Icon(
                  summary.mediaCount > 0
                      ? Icons.photo_library_outlined
                      : Icons.edit_note_rounded,
                  size: 34,
                  color: const Color(0xFF3977C9),
                ),
              ),
            if (summary.mediaCount > 1)
              PositionedDirectional(
                end: 7,
                bottom: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .64),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+${summary.mediaCount - 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _draftCard(CommunityDraftSummary summary) {
    final deleting = _deleting.contains(summary.draftId);
    final selected = _selected.contains(summary.draftId);
    final title = summary.title?.trim();
    final body = summary.body.trim();

    return FutureBuilder<
      ({CommunityPersistentDraft draft, CommunityPostImageDraft? image})
    >(
      future: _preview(summary.draftId),
      builder: (context, preview) {
        final metadata = _metadata(summary, preview.data?.draft);
        return Card(
          key: Key('community-draft-${summary.draftId}'),
          margin: const EdgeInsets.symmetric(vertical: 7),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: deleting
                ? null
                : _selecting
                ? () => _toggleSelected(summary.draftId)
                : () => widget.onOpenDraft(summary.draftId),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _previewTile(summary, preview),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title?.isNotEmpty == true
                                        ? title!
                                        : communityText(
                                            context,
                                            'Untitled draft',
                                            'مسودة بلا عنوان',
                                          ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                if (_selecting)
                                  Checkbox(
                                    value: selected,
                                    onChanged: deleting
                                        ? null
                                        : (_) =>
                                              _toggleSelected(summary.draftId),
                                  )
                                else
                                  PopupMenuButton<String>(
                                    key: Key(
                                      'community-draft-actions-${summary.draftId}',
                                    ),
                                    enabled: !deleting,
                                    tooltip: communityText(
                                      context,
                                      'Draft actions',
                                      'إجراءات المسودة',
                                    ),
                                    onSelected: (action) {
                                      if (action == 'delete') {
                                        unawaited(_delete(summary.draftId));
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        key: Key(
                                          'community-draft-delete-${summary.draftId}',
                                        ),
                                        value: 'delete',
                                        child: Text(
                                          communityText(
                                            context,
                                            'Delete draft',
                                            'حذف المسودة',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if (metadata.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                metadata.join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 5),
                            Text(
                              body.isNotEmpty
                                  ? body
                                  : communityText(
                                      context,
                                      'Saved Community draft',
                                      'مسودة مجتمع محفوظة',
                                    ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _savedLabel(summary.updatedAt),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_selecting) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: deleting
                              ? null
                              : () => widget.onOpenDraft(summary.draftId),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: Text(communityText(context, 'Edit', 'تعديل')),
                        ),
                        const Spacer(),
                        FilledButton(
                          key: Key(
                            'community-draft-continue-${summary.draftId}',
                          ),
                          onPressed: deleting
                              ? null
                              : () => widget.onOpenDraft(summary.draftId),
                          child: Text(
                            communityText(context, 'Continue', 'متابعة'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraftsContent(BuildContext context) {
    final content = Column(
      children: [
        if (!widget.fullPage)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    communityText(context, 'Drafts', 'المسودات'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: communityText(context, 'Refresh', 'تحديث'),
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        Expanded(
          child: FutureBuilder<List<CommunityDraftSummary>>(
            future: _drafts,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      communityText(context, 'Retry', 'إعادة المحاولة'),
                    ),
                  ),
                );
              }
              final drafts = snapshot.data ?? const <CommunityDraftSummary>[];
              if (drafts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 52),
                        const SizedBox(height: 14),
                        Text(
                          communityText(
                            context,
                            'No saved drafts yet',
                            'لا توجد مسودات محفوظة بعد',
                          ),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          communityText(
                            context,
                            'Save unfinished posts and continue them here later.',
                            'احفظ المنشورات غير المكتملة وتابعها هنا لاحقًا.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  key: const Key('community-drafts-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 5, 12, 18),
                  itemCount: drafts.length,
                  itemBuilder: (context, index) => _draftCard(drafts[index]),
                ),
              );
            },
          ),
        ),
        if (_selecting && _selected.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('community-drafts-delete-selected'),
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    communityText(
                      context,
                      'Delete selected ({count})',
                      'حذف المحدد ({count})',
                    ).replaceAll('{count}', '${_selected.length}'),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return widget.fullPage
        ? SizedBox.expand(child: content)
        : SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: content,
          );
  }
}
