part of 'community_hub_page.dart';

class CommunityDraftsPage extends StatefulWidget {
  const CommunityDraftsPage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<CommunityDraftsPage> createState() => _CommunityDraftsPageState();
}

class _CommunityDraftsPageState extends State<CommunityDraftsPage> {
  CommunityRepository? _repository;
  Key _listKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
  }

  @override
  void didUpdateWidget(covariant CommunityDraftsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _repository = widget.repository ?? _productionRepository();
      _listKey = UniqueKey();
    }
  }

  CommunityRepository? _productionRepository() {
    if (!AppEnvironment.communityConfigured) return null;
    try {
      final supabase = Supabase.instance;
      if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
        return null;
      }
      return CommunityRepository(supabase.client);
    } on Object {
      return null;
    }
  }

  Future<void> _openDraft(String draftId) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final loaded = await repository.loadMyCommunityDraft(draftId);
      if (!mounted) return;
      await pushCommunityPage<bool>(
        context,
        _CommunityPostComposerPage(
          repository: repository,
          imagePicker: CommunityPostImagePicker(),
          draft: _CommunityComposerDraft.fromPersistent(
            loaded.draft,
            loaded.images,
          ),
        ),
      );
      if (mounted) setState(() => _listKey = UniqueKey());
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not open this draft. Try again.',
              'تعذر فتح هذه المسودة. حاول مجددًا.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('community-drafts-page'),
    appBar: AppBar(
      title: Text(communityText(context, 'Drafts', 'المسودات')),
    ),
    body: _repository == null
        ? Center(
            child: Text(
              communityText(
                context,
                'Sign in to open your private drafts.',
                'سجّل الدخول لفتح مسوداتك الخاصة.',
              ),
            ),
          )
        : _CommunityDraftsSheet(
            key: _listKey,
            repository: _repository!,
            onOpenDraft: (draftId) => unawaited(_openDraft(draftId)),
            fullPage: true,
          ),
  );
}


extension _CommunityProfileDraftActions on _CommunityMemberProfilePageState {
  Future<void> openDrafts() async {
    final repository = _repository;
    final profile = _profile;
    if (repository == null || profile == null || !profile.isSelf) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _CommunityDraftsSheet(
        repository: repository,
        onOpenDraft: (draftId) {
          Navigator.pop(sheetContext);
          unawaited(_openPersistentDraft(draftId));
        },
      ),
    );
  }

  Future<void> _openPersistentDraft(String draftId) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final loaded = await repository.loadMyCommunityDraft(draftId);
      if (!mounted) return;
      await pushCommunityPage<bool>(
        context,
        _CommunityPostComposerPage(
          repository: repository,
          imagePicker: CommunityPostImagePicker(),
          draft: _CommunityComposerDraft.fromPersistent(
            loaded.draft,
            loaded.images,
          ),
        ),
      );
      if (mounted) await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not open this draft. Try again.',
              'تعذر فتح هذه المسودة. حاول مجددًا.',
            ),
          ),
        ),
      );
    }
  }
}

class _CommunityDraftShortcut extends StatelessWidget {
  const _CommunityDraftShortcut({required this.summary, required this.onTap});

  final CommunityDraftSummary? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = summary;
    final title = current?.title?.trim();
    final body = current?.body.trim();
    return Card(
      key: const Key('community-profile-drafts-card'),
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.drafts_outlined)),
        title: Text(
          title?.isNotEmpty == true
              ? title!
              : communityText(context, 'Drafts', 'المسودات'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          current == null
              ? communityText(
                  context,
                  'Save unfinished Community posts and continue later.',
                  'احفظ منشورات المجتمع غير المكتملة وتابعها لاحقًا.',
                )
              : body?.isNotEmpty == true
              ? body!
              : communityText(
                  context,
                  'Saved Community draft',
                  'مسودة مجتمع محفوظة',
                ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current?.mediaCount case final count? when count > 0) ...[
              const Icon(Icons.photo_library_outlined, size: 18),
              const SizedBox(width: 4),
              Text(count.toString()),
              const SizedBox(width: 6),
            ],
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityDraftsSheet extends StatefulWidget {
  const _CommunityDraftsSheet({
    required this.repository,
    required this.onOpenDraft,
    this.fullPage = false,
    super.key,
  });

  final CommunityRepository repository;
  final ValueChanged<String> onOpenDraft;
  final bool fullPage;

  @override
  State<_CommunityDraftsSheet> createState() => _CommunityDraftsSheetState();
}

class _CommunityDraftsSheetState extends State<_CommunityDraftsSheet> {
  late Future<List<CommunityDraftSummary>> _drafts = _load();
  final Set<String> _deleting = <String>{};

  Future<List<CommunityDraftSummary>> _load() =>
      widget.repository.listMyCommunityDrafts(limit: 50);

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _drafts = next);
    try {
      await next;
    } on Object {
      // FutureBuilder renders the stable failure state.
    }
  }

  Future<void> _delete(String draftId) async {
    if (!_deleting.add(draftId)) return;
    setState(() {});
    try {
      await widget.repository.deleteMyCommunityDraft(draftId);
      if (mounted) await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not delete this draft.',
              'تعذر حذف هذه المسودة.',
            ),
          ),
        ),
      );
    } finally {
      _deleting.remove(draftId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
                  child: Text(
                    communityText(
                      context,
                      'No saved drafts yet.',
                      'لا توجد مسودات محفوظة بعد.',
                    ),
                  ),
                );
              }
              return ListView.separated(
                key: const Key('community-drafts-list'),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: drafts.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final draft = drafts[index];
                  final title = draft.title?.trim();
                  final body = draft.body.trim();
                  final deleting = _deleting.contains(draft.draftId);
                  return ListTile(
                    key: Key('community-draft-${draft.draftId}'),
                    leading: const CircleAvatar(
                      child: Icon(Icons.edit_note_rounded),
                    ),
                    title: Text(
                      title?.isNotEmpty == true
                          ? title!
                          : communityText(
                              context,
                              'Untitled draft',
                              'مسودة بلا عنوان',
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      body.isNotEmpty
                          ? body
                          : draft.mediaCount > 0
                          ? communityText(context, 'Photo draft', 'مسودة صور')
                          : communityText(
                              context,
                              'Saved draft',
                              'مسودة محفوظة',
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (draft.mediaCount > 0) ...[
                          const Icon(Icons.photo_library_outlined, size: 17),
                          const SizedBox(width: 3),
                          Text(draft.mediaCount.toString()),
                        ],
                        IconButton(
                          key: Key('community-draft-delete-${draft.draftId}'),
                          tooltip: communityText(
                            context,
                            'Delete draft',
                            'حذف المسودة',
                          ),
                          onPressed: deleting
                              ? null
                              : () => _delete(draft.draftId),
                          icon: deleting
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline_rounded),
                        ),
                        Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                        ),
                      ],
                    ),
                    onTap: deleting
                        ? null
                        : () => widget.onOpenDraft(draft.draftId),
                  );
                },
              );
            },
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
