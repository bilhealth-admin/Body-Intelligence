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
    final mediaCount = draft?.media.length ?? summary.mediaCount;
    if (mediaCount > 0) {
      values.add(
        communityText(
          context,
          '{count} photos',
          '{count} صور',
        ).replaceAll('{count}', '$mediaCount'),
      );
    }
    if (draft?.pollQuestion?.trim().isNotEmpty == true) {
      values.add(communityText(context, 'Poll', 'استطلاع'));
    } else if (draft != null) {
      values.add(communityText(context, 'No poll', 'بلا استطلاع'));
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

  Widget _draftCard(CommunityDraftSummary summary) {
    final deleting = _deleting.contains(summary.draftId);
    final selected = _selected.contains(summary.draftId);
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<_CommunityDraftMosaicPreview>(
      future: _preview(summary.draftId),
      builder: (context, preview) {
        final draft = preview.data?.draft;
        // A cross-device edit may be newer than the list summary. Display one
        // authoritative revision for its text, timestamp, and media together.
        final title = (draft == null ? summary.title : draft.title)?.trim();
        final body = (draft?.body ?? summary.body).trim();
        final metadata = _metadata(summary, draft);
        return Card(
          key: Key('community-draft-${summary.draftId}'),
          margin: const EdgeInsets.symmetric(vertical: 6),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: InkWell(
            onTap: deleting
                ? null
                : _selecting
                ? () => _toggleSelected(summary.draftId)
                : () => widget.onOpenDraft(summary.draftId),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final previewWidth = (constraints.maxWidth * .325)
                      .clamp(84.0, 118.0)
                      .toDouble();
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _previewTile(summary, preview, previewWidth),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            if (metadata.isNotEmpty)
                              Text(
                                metadata.join(' • '),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            const SizedBox(height: 6),
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
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _savedLabel(
                                draft?.updatedAt ?? summary.updatedAt,
                              ),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            if (!_selecting) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  OutlinedButton(
                                    onPressed: deleting
                                        ? null
                                        : () => widget.onOpenDraft(
                                            summary.draftId,
                                          ),
                                    child: Text(
                                      communityText(context, 'Edit', 'تعديل'),
                                    ),
                                  ),
                                  FilledButton(
                                    key: Key(
                                      'community-draft-continue-${summary.draftId}',
                                    ),
                                    onPressed: deleting
                                        ? null
                                        : () => widget.onOpenDraft(
                                            summary.draftId,
                                          ),
                                    child: Text(
                                      communityText(
                                        context,
                                        'Continue',
                                        'متابعة',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
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
        if (widget.fullPage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                communityText(
                  context,
                  'Your drafts are always accessible.',
                  'مسوداتك متاحة دائمًا.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
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
              final drafts = _loadedRows;
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
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 18),
                  itemCount: drafts.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) => index < drafts.length
                      ? _draftCard(drafts[index])
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: OutlinedButton.icon(
                              key: const Key('community-drafts-load-more'),
                              onPressed: _loadingMore ? null : _loadMore,
                              icon: _loadingMore
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _loadMoreFailed
                                          ? Icons.refresh_rounded
                                          : Icons.expand_more_rounded,
                                    ),
                              label: Text(
                                _loadMoreFailed
                                    ? communityText(
                                        context,
                                        'Retry',
                                        'إعادة المحاولة',
                                      )
                                    : communityText(
                                        context,
                                        'Load more',
                                        'تحميل المزيد',
                                      ),
                              ),
                            ),
                          ),
                        ),
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
