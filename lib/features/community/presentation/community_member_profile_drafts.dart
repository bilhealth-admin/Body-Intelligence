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
      final loaded = await repository.loadMyCommunityDraft(draftId);
      if (!mounted || !_sameOwnerOperation(repository, owner, generation)) {
        return;
      }
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
                ).replaceAll('{count}', '$count'),
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
    this.onSelectionChanged,
    this.fullPage = false,
    super.key,
  });

  final CommunityRepository repository;
  final ValueGetter<bool> ownerIsCurrent;
  final ValueChanged<String> onOpenDraft;
  final ValueChanged<int>? onCountChanged;
  final ValueChanged<bool>? onSelectionChanged;
  final bool fullPage;

  @override
  State<_CommunityDraftsSheet> createState() => _CommunityDraftsSheetState();
}

class _CommunityDraftsSheetState extends State<_CommunityDraftsSheet> {
  late final CommunityRepository _repository = widget.repository;
  late final String? _ownerId = _communityDraftOwnerId(_repository);
  late Future<List<CommunityDraftSummary>> _drafts = _load();
  final Set<String> _deleting = <String>{};
  final Set<String> _selected = <String>{};
  final Map<
    String,
    Future<({CommunityPersistentDraft draft, CommunityPostImageDraft? image})>
  >
  _previews = {};
  bool _selecting = false;
  int _generation = 0;

  bool get _sameOwner =>
      mounted &&
      widget.ownerIsCurrent() &&
      identical(_repository, widget.repository) &&
      _ownerId != null &&
      _ownerId == _communityDraftOwnerId(_repository);

  Future<List<CommunityDraftSummary>> _load() async {
    if (!_sameOwner) throw StateError('Community draft owner changed');
    final generation = _generation;
    final rows = await _repository.listMyCommunityDrafts(limit: 50);
    if (!_sameOwner || generation != _generation) {
      throw StateError('Community draft owner changed');
    }
    widget.onCountChanged?.call(rows.length);
    return rows;
  }

  Future<({CommunityPersistentDraft draft, CommunityPostImageDraft? image})>
  _preview(String draftId) {
    final cached = _previews[draftId];
    if (cached != null) return cached;
    final generation = _generation;
    final next = () async {
      if (!_sameOwner) throw StateError('Community draft owner changed');
      final value = await _repository.loadMyCommunityDraftPreview(draftId);
      if (!_sameOwner || generation != _generation) {
        throw StateError('Community draft owner changed');
      }
      return value;
    }();
    _previews[draftId] = next;
    return next;
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    if (!_sameOwner) return;
    _generation++;
    _previews.clear();
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
      await _repository.deleteMyCommunityDraft(draftId);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildDraftsContent(context);
}
