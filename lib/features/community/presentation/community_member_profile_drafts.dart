part of 'community_hub_page.dart';

class CommunityDraftsPage extends StatefulWidget {
  const CommunityDraftsPage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<CommunityDraftsPage> createState() => _CommunityDraftsPageState();
}

class _CommunityDraftsPageState extends State<CommunityDraftsPage> {
  CommunityRepository? _repository;
  final _draftsKey = GlobalKey<_CommunityDraftsSheetState>();
  int? _draftCount;
  bool _selecting = false;

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
      _draftCount = null;
      _selecting = false;
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

  String? _owner(CommunityRepository? repository) {
    try {
      return repository?.currentUserId;
    } on Object {
      return null;
    }
  }

  Future<void> _openDraft(String draftId) async {
    final repository = _repository;
    final owner = _owner(repository);
    if (repository == null || owner == null) return;
    try {
      final loaded = await repository.loadMyCommunityDraft(draftId);
      if (!mounted || _owner(repository) != owner) return;
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
      if (mounted && _owner(repository) == owner) {
        await _draftsKey.currentState?.refresh();
      }
    } on Object {
      if (!mounted || _owner(repository) != owner) return;
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
  Widget build(BuildContext context) {
    final count = _draftCount;
    return Scaffold(
      key: const Key('community-drafts-page'),
      appBar: AppBar(
        title: Text(
          count == null
              ? communityText(context, 'Drafts', 'المسودات')
              : communityText(
                  context,
                  'Drafts ($count)',
                  'المسودات ($count)',
                ),
        ),
        actions: [
          if (_repository != null && (count ?? 0) > 0)
            TextButton(
              key: const Key('community-drafts-select'),
              onPressed: () => _draftsKey.currentState?.toggleSelection(),
              child: Text(
                _selecting
                    ? communityText(context, 'Done', 'تم')
                    : communityText(context, 'Select', 'تحديد'),
              ),
            ),
        ],
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
              key: _draftsKey,
              repository: _repository!,
              onOpenDraft: (draftId) => unawaited(_openDraft(draftId)),
              onCountChanged: (value) {
                if (mounted && value != _draftCount) {
                  setState(() => _draftCount = value);
                }
              },
              onSelectionChanged: (value) {
                if (mounted && value != _selecting) {
                  setState(() => _selecting = value);
                }
              },
              fullPage: true,
            ),
    );
  }
}

class _CommunityDraftsSheet extends StatefulWidget {
  const _CommunityDraftsSheet({
    required this.repository,
    required this.onOpenDraft,
    this.onCountChanged,
    this.onSelectionChanged,
    this.fullPage = false,
    super.key,
  });

  final CommunityRepository repository;
  final ValueChanged<String> onOpenDraft;
  final ValueChanged<int>? onCountChanged;
  final ValueChanged<bool>? onSelectionChanged;
  final bool fullPage;

  @override
  State<_CommunityDraftsSheet> createState() => _CommunityDraftsSheetState();
}

class _CommunityDraftsSheetState extends State<_CommunityDraftsSheet> {
  late Future<List<CommunityDraftSummary>> _drafts;
  final Set<String> _deleting = <String>{};
  final Set<String> _selected = <String>{};
  final Map<
    String,
    Future<({CommunityPersistentDraft draft, CommunityPostImageDraft? image})>
  >
  _previews = {};
  StreamSubscription<AuthState>? _auth;
  String? _owner;
  bool _selecting = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _bindOwner();
    _drafts = _load();
  }

  @override
  void didUpdateWidget(covariant _CommunityDraftsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      unawaited(_auth?.cancel());
      _generation++;
      _selected.clear();
      _previews.clear();
      _selecting = false;
      _bindOwner();
      _drafts = _load();
    }
  }

  String? _currentOwner() {
    try {
      return widget.repository.currentUserId;
    } on Object {
      return null;
    }
  }

  void _bindOwner() {
    _owner = _currentOwner();
    _auth = widget.repository.communitySocialClient.auth.onAuthStateChange.listen(
      (_) {
        if (!mounted) return;
        final next = _currentOwner();
        if (next == _owner) return;
        _generation++;
        setState(() {
          _owner = next;
          _selected.clear();
          _previews.clear();
          _selecting = false;
          _drafts = _load();
        });
        widget.onSelectionChanged?.call(false);
      },
      onError: (Object _, StackTrace _) {
        // Auth owns recovery; draft UI never manufactures a session.
      },
    );
  }

  Future<List<CommunityDraftSummary>> _load() async {
    final owner = _currentOwner();
    if (owner == null) throw const AuthException('Sign-in required');
    final generation = _generation;
    final rows = await widget.repository.listMyCommunityDrafts(limit: 50);
    if (generation != _generation || _currentOwner() != owner) {
      throw StateError('Community draft owner changed');
    }
    widget.onCountChanged?.call(rows.length);
    return rows;
  }

  Future<
    ({CommunityPersistentDraft draft, CommunityPostImageDraft? image})
  >
  _preview(String draftId) {
    final cached = _previews[draftId];
    if (cached != null) return cached;
    final owner = _currentOwner();
    final generation = _generation;
    final next = widget.repository.loadMyCommunityDraftPreview(draftId).then(
      (value) {
        if (generation != _generation || _currentOwner() != owner) {
          throw StateError('Community draft owner changed');
        }
        return value;
      },
    );
    _previews[draftId] = next;
    return next;
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    _generation++;
    _previews.clear();
    final next = _load();
    if (mounted) setState(() => _drafts = next);
    try {
      await next;
    } on Object {
      // FutureBuilder renders the stable failure state.
    }
  }

  void toggleSelection() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selected.clear();
    });
    widget.onSelectionChanged?.call(_selecting);
  }

  void _toggleSelected(String draftId) {
    setState(() {
      if (!_selected.add(draftId)) _selected.remove(draftId);
    });
  }

  Future<void> _delete(String draftId) async {
    if (!_deleting.add(draftId)) return;
    final owner = _currentOwner();
    final generation = _generation;
    setState(() {});
    try {
      await widget.repository.deleteMyCommunityDraft(draftId);
      if (!mounted ||
          generation != _generation ||
          _currentOwner() != owner) {
        return;
      }
      _selected.remove(draftId);
      await _refresh();
    } catch (_) {
      if (!mounted ||
          generation != _generation ||
          _currentOwner() != owner) {
        return;
      }
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
      if (mounted && generation == _generation) setState(() {});
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          communityText(
            context,
            'Delete $count drafts?',
            'حذف $count من المسودات؟',
          ),
        ),
        content: Text(
          communityText(
            context,
            'This removes only the selected private drafts.',
            'سيؤدي هذا إلى حذف المسودات الخاصة المحددة فقط.',
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
    for (final id in _selected.toList(growable: false)) {
      await _delete(id);
      if (!mounted) return;
    }
    if (mounted && _selecting) toggleSelection();
  }

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
        'Last saved ${delta.inMinutes}m ago',
        'آخر حفظ قبل ${delta.inMinutes} د',
      );
    }
    if (delta.inDays < 1) {
      return communityText(
        context,
        'Last saved ${delta.inHours}h ago',
        'آخر حفظ قبل ${delta.inHours} س',
      );
    }
    return communityText(
      context,
      'Last saved ${delta.inDays}d ago',
      'آخر حفظ قبل ${delta.inDays} ي',
    );
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
          '${summary.mediaCount} photos',
          '${summary.mediaCount} صور',
        ),
      );
    }
    if (draft?.pollQuestion?.trim().isNotEmpty == true) {
      values.add(communityText(context, 'Poll', 'استطلاع'));
    }
    if (draft?.topicSlugs.isNotEmpty == true) {
      values.add(
        CommunityTaxonomySheet.titleForSlug(
          context,
          draft!.topicSlugs.first,
        ),
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
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _savedLabel(summary.updatedAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
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
                          label: Text(
                            communityText(context, 'Edit', 'تعديل'),
                          ),
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

  @override
  void dispose() {
    _generation++;
    unawaited(_auth?.cancel());
    super.dispose();
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
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
                      'Delete selected (${_selected.length})',
                      'حذف المحدد (${_selected.length})',
                    ),
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
