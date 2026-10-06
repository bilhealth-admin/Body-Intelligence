part of 'community_hub_page.dart';

class CommunityDraftsPage extends StatefulWidget {
  const CommunityDraftsPage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<CommunityDraftsPage> createState() => _CommunityDraftsPageState();
}

String? _communityDraftOwnerId(CommunityRepository? repository) {
  try {
    return repository?.currentUserId;
  } on Object {
    return null;
  }
}

class _CommunityDraftsPageState extends State<CommunityDraftsPage> {
  CommunityRepository? _repository;
  GlobalKey<_CommunityDraftsSheetState> _draftsKey = GlobalKey();
  String? _ownerId;
  StreamSubscription<AuthState>? _authSubscription;
  int _sessionBinding = 0;
  int _generation = 0;
  String? _openingDraftId;
  int? _draftCount;
  bool _draftCountIsLowerBound = false;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _bindRepository();
  }

  @override
  void didUpdateWidget(covariant CommunityDraftsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        _communityDraftOwnerId(widget.repository ?? _repository) != _ownerId) {
      _bindRepository();
    }
  }

  SupabaseClient? _productionClient() {
    if (!AppEnvironment.communityConfigured) return null;
    try {
      final supabase = Supabase.instance;
      return supabase.isInitialized ? supabase.client : null;
    } on Object {
      return null;
    }
  }

  CommunityRepository? _productionRepository() {
    final client = _productionClient();
    return client?.auth.currentUser == null
        ? null
        : CommunityRepository(client!);
  }

  void _invalidateOwnerWork() {
    _generation++;
    _openingDraftId = null;
    _draftsKey = GlobalKey();
    _draftCount = null;
    _draftCountIsLowerBound = false;
    _selecting = false;
  }

  void _bindRepository() {
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
    final binding = ++_sessionBinding;
    _repository = widget.repository ?? _productionRepository();
    _ownerId = _communityDraftOwnerId(_repository);
    _invalidateOwnerWork();
    final client = _repository?.communitySocialClient ?? _productionClient();
    if (client == null) return;
    var sessionOwner = client.auth.currentUser?.id;
    _authSubscription = client.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted || binding != _sessionBinding) return;
        final changedSession = state.session?.user.id != sessionOwner;
        sessionOwner = state.session?.user.id;
        final repository = widget.repository ?? _productionRepository();
        final owner = _communityDraftOwnerId(repository);
        if (!changedSession && owner == _ownerId) return;
        setState(() {
          _repository = repository;
          _ownerId = owner;
          // Event identity also cancels A -> B -> A work before another frame.
          _invalidateOwnerWork();
        });
      },
      onError: (Object _, StackTrace _) {
        // Auth owns refresh/recovery; a stream error does not invent a logout.
      },
    );
  }

  bool _sameOwnerOperation(
    CommunityRepository repository,
    String owner,
    int generation,
  ) =>
      mounted &&
      generation == _generation &&
      identical(repository, _repository) &&
      owner == _ownerId &&
      owner == _communityDraftOwnerId(repository);

  @override
  void dispose() {
    _generation++;
    _sessionBinding++;
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  Future<void> _openDraft(String draftId) async {
    final repository = _repository;
    final owner = _ownerId;
    final generation = _generation;
    if (repository == null ||
        owner == null ||
        _openingDraftId != null ||
        !_sameOwnerOperation(repository, owner, generation)) {
      return;
    }
    _openingDraftId = draftId;
    try {
      final loaded = await repository.runForCommunityOwner(
        () => repository.loadMyCommunityDraft(draftId),
        ownerId: owner,
        isCurrentOwner: () =>
            _sameOwnerOperation(repository, owner, generation),
      );
      if (!mounted || !_sameOwnerOperation(repository, owner, generation)) {
        return;
      }
      await pushCommunityPage<bool>(
        context,
        _CommunityPostComposerPage(
          repository: repository,
          ownerIsCurrent: () =>
              _sameOwnerOperation(repository, owner, generation),
          imagePicker: CommunityPostImagePicker(),
          draft: _CommunityComposerDraft.fromPersistent(
            loaded.draft,
            loaded.images,
          ),
        ),
      );
      if (_sameOwnerOperation(repository, owner, generation)) {
        await _draftsKey.currentState?.refresh();
      }
    } on Object {
      if (!mounted || !_sameOwnerOperation(repository, owner, generation)) {
        return;
      }
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
    } finally {
      if (_sameOwnerOperation(repository, owner, generation)) {
        _openingDraftId = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _draftCount;
    final repository = _repository;
    final owner = _ownerId;
    final generation = _generation;
    bool sameOwner() =>
        repository != null &&
        owner != null &&
        _sameOwnerOperation(repository, owner, generation);
    return Scaffold(
      key: const Key('community-drafts-page'),
      appBar: AppBar(
        leading: const CommunityReturnButton(),
        title: Text(
          count == null
              ? communityText(context, 'Drafts', 'المسودات')
              : communityText(
                  context,
                  'Drafts ({count})',
                  'المسودات ({count})',
                ).replaceAll(
                  '{count}',
                  '$count${_draftCountIsLowerBound ? '+' : ''}',
                ),
        ),
        actions: [
          if (repository != null && owner != null && (count ?? 0) > 0)
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
      body: repository == null || owner == null
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
              repository: repository,
              ownerIsCurrent: sameOwner,
              onOpenDraft: (draftId) {
                if (sameOwner()) unawaited(_openDraft(draftId));
              },
              onCountChanged: (value) {
                if (sameOwner() && value != _draftCount) {
                  setState(() => _draftCount = value);
                }
              },
              onHasMoreChanged: (value) {
                if (sameOwner() && value != _draftCountIsLowerBound) {
                  setState(() => _draftCountIsLowerBound = value);
                }
              },
              onSelectionChanged: (value) {
                if (sameOwner() && value != _selecting) {
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
    required this.ownerIsCurrent,
    required this.onOpenDraft,
    this.onCountChanged,
    this.onHasMoreChanged,
    this.onSelectionChanged,
    this.fullPage = false,
    super.key,
  });

  final CommunityRepository repository;
  final ValueGetter<bool> ownerIsCurrent;
  final ValueChanged<String> onOpenDraft;
  final ValueChanged<int>? onCountChanged;
  final ValueChanged<bool>? onHasMoreChanged;
  final ValueChanged<bool>? onSelectionChanged;
  final bool fullPage;

  @override
  State<_CommunityDraftsSheet> createState() => _CommunityDraftsSheetState();
}

typedef _CommunityDraftMosaicPreview = ({
  CommunityPersistentDraft draft,
  List<CommunityPostImagePreview?> images,
});

class _CommunityDraftsSheetState extends State<_CommunityDraftsSheet> {
  static const _pageSize = 20;
  // At most12 complete results ×4 display-only images ×64KiB =3MiB encoded
  // bytes. Original uploads never enter this cache or trigger byte eviction.
  static const _previewCacheSize = 12;
  static const _parallelPreviews = 2;
  final List<CommunityDraftSummary> _loadedRows = [];
  DateTime? _before;
  String? _beforeId;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  int _activePreviews = 0;
  final List<Completer<void>> _previewWaiters = [];
  late final CommunityRepository _repository = widget.repository;
  late final String? _ownerId = _communityDraftOwnerId(_repository);
  late Future<List<CommunityDraftSummary>> _drafts = _load();
  final Set<String> _deleting = <String>{};
  final Set<String> _selected = <String>{};
  final Map<String, Future<_CommunityDraftMosaicPreview>> _previews = {};
  bool _selecting = false;
  int _generation = 0;

  bool get _sameOwner =>
      mounted &&
      widget.ownerIsCurrent() &&
      identical(_repository, widget.repository) &&
      _ownerId != null &&
      _ownerId == _communityDraftOwnerId(_repository);

  bool _sameGeneration(int generation) =>
      _sameOwner && generation == _generation;

  Future<T> _runDraftVisit<T>(int generation, Future<T> Function() action) {
    if (!_sameGeneration(generation)) {
      throw const CommunityOwnerOperationCancelled();
    }
    return _repository.runForCommunityOwner(
      action,
      ownerId: _ownerId!,
      isCurrentOwner: () => _sameGeneration(generation),
    );
  }

  void _reportCount() {
    widget.onCountChanged?.call(_loadedRows.length);
    widget.onHasMoreChanged?.call(_hasMore);
  }

  Future<List<CommunityDraftSummary>> _load() async {
    final generation = _generation;
    final rows = await _runDraftVisit(
      generation,
      () => _repository.listMyCommunityDrafts(limit: _pageSize),
    );
    if (!_sameGeneration(generation)) {
      throw const CommunityOwnerOperationCancelled();
    }
    _loadedRows
      ..clear()
      ..addAll(rows);
    _before = rows.lastOrNull?.updatedAt;
    _beforeId = rows.lastOrNull?.draftId;
    _hasMore = rows.length == _pageSize;
    _reportCount();
    return List<CommunityDraftSummary>.unmodifiable(_loadedRows);
  }

  Future<void> _loadMore() async {
    if (!_sameOwner || !_hasMore || _loadingMore) return;
    final generation = _generation;
    final before = _before;
    final beforeId = _beforeId;
    if (before == null || beforeId == null) return;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final rows = await _runDraftVisit(
        generation,
        () => _repository.listMyCommunityDrafts(
          before: before,
          beforeId: beforeId,
          limit: _pageSize,
        ),
      );
      if (!_sameGeneration(generation)) return;
      if (rows.isNotEmpty &&
          rows.last.updatedAt == before &&
          rows.last.draftId == beforeId) {
        throw const FormatException('Community draft cursor did not advance');
      }
      final known = _loadedRows.map((row) => row.draftId).toSet();
      for (final row in rows) {
        if (known.add(row.draftId)) _loadedRows.add(row);
      }
      _before = rows.lastOrNull?.updatedAt;
      _beforeId = rows.lastOrNull?.draftId;
      _hasMore = rows.length == _pageSize;
      _reportCount();
      // Keep the completed list future and its Scrollable mounted. Replacing
      // it here produces a loading frame and loses the user's page position.
      setState(() {});
    } on Object {
      if (_sameGeneration(generation)) {
        setState(() => _loadMoreFailed = true);
      }
    } finally {
      if (_sameGeneration(generation)) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _acquirePreview(int generation) async {
    while (_activePreviews >= _parallelPreviews) {
      final waiter = Completer<void>();
      _previewWaiters.add(waiter);
      await waiter.future;
      if (!_sameGeneration(generation)) {
        throw const CommunityOwnerOperationCancelled();
      }
    }
    if (!_sameGeneration(generation)) {
      throw const CommunityOwnerOperationCancelled();
    }
    _activePreviews++;
  }

  void _releasePreview() {
    _activePreviews--;
    if (_previewWaiters.isNotEmpty) {
      _previewWaiters.removeAt(0).complete();
    }
  }

  void _wakeCancelledPreviews() {
    for (final waiter in _previewWaiters) {
      waiter.complete();
    }
    _previewWaiters.clear();
  }

  Future<_CommunityDraftMosaicPreview> _preview(String draftId) {
    final cached = _previews.remove(draftId);
    if (cached != null) {
      _previews[draftId] = cached;
      return cached;
    }
    final generation = _generation;
    final next = _runDraftVisit(generation, () async {
      await _acquirePreview(generation);
      try {
        final value = await _repository.loadMyCommunityDraftMosaicPreview(
          draftId,
          maxImages: 4,
        );
        CommunityOwnerOperation.checkCurrent();
        return value;
      } finally {
        _releasePreview();
      }
    });
    _previews[draftId] = next;
    while (_previews.length > _previewCacheSize) {
      _previews.remove(_previews.keys.first);
    }
    return next;
  }

  void _retryPreview(String draftId) {
    if (!_sameOwner) return;
    setState(() {
      _previews.remove(draftId);
    });
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    if (!_sameOwner) return;
    _generation++;
    _wakeCancelledPreviews();
    _previews.clear();
    _loadingMore = false;
    _loadMoreFailed = false;
    _selected.clear();
    final next = _load();
    setState(() {
      _drafts = next;
    });
    try {
      await next;
    } on Object {
      // FutureBuilder renders the stable failure state.
    }
  }

  void toggleSelection() {
    if (!_sameOwner) return;
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selected.clear();
    });
    widget.onSelectionChanged?.call(_selecting);
  }

  void _toggleSelected(String draftId) {
    if (!_sameOwner || _deleting.contains(draftId)) return;
    setState(() {
      if (!_selected.add(draftId)) _selected.remove(draftId);
    });
  }

  Future<void> _delete(String draftId) async {
    if (!_sameOwner || !_deleting.add(draftId)) return;
    setState(() {});
    try {
      await _repository.runForCommunityOwner(
        () => _repository.deleteMyCommunityDraft(draftId),
        ownerId: _ownerId!,
        isCurrentOwner: () => _sameOwner,
      );
      if (!_sameOwner) return;
      _selected.remove(draftId);
      await _refresh();
    } on Object {
      if (!mounted || !_sameOwner) return;
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
      if (_sameOwner) {
        setState(() {
          _deleting.remove(draftId);
        });
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (!_sameOwner || _selected.isEmpty) return;
    // Both the selection and its owner are fixed before the dialog yields.
    final selected = _selected.toList(growable: false);
    final count = selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          communityText(
            dialogContext,
            'Delete {count} drafts?',
            'حذف {count} من المسودات؟',
          ).replaceAll('{count}', '$count'),
        ),
        content: Text(
          communityText(
            dialogContext,
            'This removes only the selected private drafts.',
            'سيؤدي هذا إلى حذف المسودات الخاصة المحددة فقط.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(communityText(dialogContext, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(communityText(dialogContext, 'Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed != true || !_sameOwner) return;
    for (final id in selected) {
      if (!_sameOwner) return;
      await _delete(id);
    }
    if (_sameOwner && _selecting) toggleSelection();
  }

  @override
  void dispose() {
    _generation++;
    _wakeCancelledPreviews();
    _previews.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildDraftsContent(context);
}
