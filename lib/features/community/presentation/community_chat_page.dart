part of 'community_people_page.dart';

class CommunityChatPage extends StatefulWidget {
  const CommunityChatPage({
    super.key,
    required this.userId,
    required this.displayName,
    this.repository,
  });
  final String userId, displayName;
  final CommunityRepository? repository;
  @override
  State<CommunityChatPage> createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends State<CommunityChatPage> {
  CommunityRepository? _repository;
  final _composer = TextEditingController();
  final _composerAnchor = GlobalKey();
  final _presentation = BilConversationPresentation();
  final _historyScroll = ScrollController(keepScrollOffset: false);
  Future<List<CommunityMessage>> _messages = Future.value(const []);
  StreamSubscription<void>? _conversationChanges;
  StreamSubscription<AuthState>? _auth;
  String? _ownerId, _peerId;
  bool _ownerCancelled = false;
  int _binding = 0, _loadGeneration = 0, _composerRevision = 0;
  int? _emojiBinding;
  int _readRetry = 0;
  bool _hasOlder = false, _loadingOlder = false;
  List<CommunityMessage> _rows = const [];
  TextDirection? _composerDirection;
  bool _sending = false;
  bool _safetyBusy = false;
  bool _safetyBlocked = false;
  bool _confirmingReplacement = false;
  String? _sendRequestId, _sendRequestBody;
  bool _removedDelivery = false;

  @override
  void initState() {
    super.initState();
    _composer.addListener(_composerEdited);
    _bind();
  }

  void _setChatState(VoidCallback update) => setState(update);

  void _composerEdited() {
    _composerRevision++;
  }

  @override
  void didUpdateWidget(covariant CommunityChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.userId != widget.userId) {
      _retire();
      _composer.clear();
      _sendRequestId = _sendRequestBody = null;
      _removedDelivery = false;
      _composerDirection = null;
      _bind();
    }
  }

  void _watchConversation() {
    final binding = _binding;
    try {
      _conversationChanges = _repository
          ?.watchConversationChanges(widget.userId)
          .listen((_) {
            if (_current(binding)) setState(_reload);
          }, onError: (Object _, StackTrace _) {});
    } on AuthException {
      _conversationChanges = null;
    } on ArgumentError {
      _conversationChanges = null;
    }
  }

  Future<List<CommunityMessage>> _loadConversation() async {
    final binding = _binding;
    final generation = ++_loadGeneration;
    final repository = _repository!;
    final peer = _peerId!;
    final messages = await _run(binding, () => repository.loadMessages(peer));
    _check(binding);
    if (generation != _loadGeneration) return _rows;
    final older = messages.length == 50 && messages.isNotEmpty
        ? _rows.where((row) => _compareMessages(row, messages.first) < 0)
        : const <CommunityMessage>[];
    _rows = _mergeMessages([...older, ...messages]);
    _observeMessagePresentation();
    _hasOlder = older.isNotEmpty ? _hasOlder : messages.length == 50;
    return _rows;
  }

  void _observeMessagePresentation() {
    _presentation.observe(
      _rows.map(
        (row) => BilConversationPresentationRow(
          id: row.id,
          text: row.body,
          mine: row.senderId == _ownerId,
          createdAt: row.createdAt,
        ),
      ),
    );
  }

  void _reload() {
    if (_current(_binding)) _messages = _loadConversation();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasOlder || _rows.isEmpty) return;
    final binding = _binding;
    final generation = _loadGeneration;
    final repository = _repository!;
    final peer = _peerId!;
    final before = _rows.first;
    setState(() => _loadingOlder = true);
    try {
      final older = await _run(
        binding,
        () => repository.loadOlderMessages(
          peer,
          before: before.createdAt,
          beforeId: before.id,
        ),
      );
      if (!mounted || !_current(binding) || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _rows = _mergeMessages([...older, ..._rows]);
        _observeMessagePresentation();
        _hasOlder = older.length == 50;
        _messages = Future.value(_rows);
      });
    } on Object {
      // The same cursor and existing rows remain available for explicit retry.
    } finally {
      if (mounted && _current(binding)) setState(() => _loadingOlder = false);
    }
  }

  Future<Set<String>> _markSeen(int binding, List<String> ids) async {
    final repository = _repository!;
    final peer = _peerId!;
    return _run(binding, () async {
      await repository.markVisibleMessagesRead(ids);
      _check(binding);
      final confirmed = await repository.loadReadMessageIds(peer, ids);
      _check(binding);
      if (!mounted) throw const CommunityOwnerOperationCancelled();
      await CommunityAttentionScope.refresh(context);
      _check(binding);
      return confirmed.intersection(ids.toSet());
    });
  }

  void _updateComposerDirection(String value) {
    if (!_current(_binding)) return;
    setState(
      () => _composerDirection = BilWrittenLanguageResolver.directionFor(
        value,
        fallback: Directionality.of(context),
      ),
    );
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    final binding = _binding;
    final repository = _repository;
    final peer = _peerId;
    final revision = _composerRevision;
    if (body.isEmpty ||
        _sending ||
        repository == null ||
        peer == null ||
        !_current(binding)) {
      return;
    }
    if (body.runes.length > 2000) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageLimitText(context))));
      return;
    }
    setState(() => _sending = true);
    // Sending is an explicit request to follow the conversation end. Do this
    // now, not after the async reply when the user might be reading history.
    if (_historyScroll.hasClients) {
      _historyScroll.jumpTo(_historyScroll.position.minScrollExtent);
    }
    var visualRequestSucceeded = false;
    try {
      if (_removedDelivery) {
        setState(() => _confirmingReplacement = true);
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => BilPearlMaterialAlertDialog(
            key: const Key('community-message-replacement-confirmation'),
            title: Text(
              communityText(
                context,
                'Send a new message?',
                'إرسال رسالة جديدة؟',
              ),
            ),
            content: Text(
              communityText(
                context,
                'The previous request was delivered and then removed. Sending again creates a new message.',
                'أُرسلت الرسالة السابقة ثم أُزيلت. الإرسال مرة أخرى ينشئ رسالة جديدة.',
              ),
            ),
            actions: [
              TextButton(
                key: const Key('community-message-replacement-cancel'),
                onPressed: () => Navigator.pop(context, false),
                child: Text(communityText(context, 'Cancel', 'إلغاء')),
              ),
              FilledButton(
                key: const Key('community-message-replacement-send'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  communityText(
                    context,
                    'Send new message',
                    'إرسال رسالة جديدة',
                  ),
                ),
              ),
            ],
          ),
        );
        if (mounted && _current(binding)) {
          setState(() => _confirmingReplacement = false);
        }
        if (replace != true || !mounted || !_current(binding)) return;
        _sendRequestId = _sendRequestBody = null;
        _removedDelivery = false;
      }
      if (_sendRequestId == null || _sendRequestBody != body) {
        _sendRequestId = newCommunityMessageRequestId();
        _sendRequestBody = body;
      }
      final composerBox = _composerAnchor.currentContext?.findRenderObject();
      _presentation.beginSend(
        body,
        composerBox is RenderBox && composerBox.attached && composerBox.hasSize
            ? composerBox.localToGlobal(Offset.zero) & composerBox.size
            : null,
      );
      await _run(
        binding,
        () => repository.sendMessageOperation(
          peer,
          body,
          requestId: _sendRequestId!,
        ),
      );
      if (!mounted || !_current(binding)) return;
      visualRequestSucceeded = true;
      _presentation.confirmSend();
      _sendRequestId = _sendRequestBody = null;
      if (_composerRevision == revision && _composer.text.trim() == body) {
        _composer.clear();
      }
      setState(_reload);
    } on CommunityMessageDeliveryRemoved {
      if (!mounted || !_current(binding)) return;
      setState(() => _removedDelivery = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'أُرسلت هذه الرسالة سابقًا ثم أُزيلت. النص محفوظ؛ لم نرسل رسالة أخرى.',
              'This message was previously delivered and then removed. Your text is kept; no new message was sent.',
              'Ce message a été envoyé puis supprimé. Votre texte est conservé ; aucun nouveau message n’a été envoyé.',
              'Este mensaje se envió y luego se eliminó. Conservamos tu texto; no se envió otro mensaje.',
              'Bu mesaj daha önce iletildi ve ardından kaldırıldı. Metniniz korundu; yeni mesaj gönderilmedi.',
            ),
          ),
        ),
      );
    } on TimeoutException {
      if (!mounted || !_current(binding)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Sending could not be confirmed yet. Your text is kept; retry checks the same request.',
              'لم يتأكد الإرسال بعد. النص محفوظ؛ إعادة المحاولة تتحقق من الطلب نفسه.',
            ),
          ),
        ),
      );
    } on CommunityMessageDeliveryUnavailable {
      if (!mounted || !_current(binding)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Sending is unavailable on this server. Your text is kept. Try again later.',
              'الإرسال غير متاح على هذا الخادم. احتفظنا بالنص؛ حاول لاحقًا.',
            ),
          ),
        ),
      );
    } on CommunityPolicyAccessException catch (error) {
      if (!mounted || !_current(binding)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              error.englishMessage(CommunityPolicyProtectedAction.messaging),
              error.arabicMessage(CommunityPolicyProtectedAction.messaging),
            ),
          ),
          action: SnackBarAction(
            label: communityText(context, 'Review policy', 'مراجعة السياسة'),
            onPressed: () {
              if (_current(binding)) {
                unawaited(
                  showCommunityMessagingPolicy(
                    context,
                    repository: repository,
                    isCurrent: () => _current(binding),
                  ),
                );
              }
            },
          ),
        ),
      );
    } on CommunityMembershipAccessException catch (error) {
      if (!mounted || !_current(binding)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              error.englishMessage(CommunityPolicyProtectedAction.messaging),
              error.arabicMessage(CommunityPolicyProtectedAction.messaging),
            ),
          ),
        ),
      );
    } on CommunityTextPolicyException catch (error) {
      if (!mounted || !_current(binding)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.localizedMessage(
              Localizations.localeOf(context).toLanguageTag(),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted || !_current(binding)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'تعذر إرسال الرسالة. احتفظنا بالنص.',
              'Message could not be sent. Your text is kept.',
              'Message non envoyé. Votre texte est conservé.',
              'No se pudo enviar. Conservamos tu texto.',
              'Mesaj gönderilemedi. Metniniz korundu.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && _current(binding)) {
        if (!visualRequestSucceeded) _presentation.abandonSend();
        setState(() {
          _sending = false;
          _confirmingReplacement = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _retire();
    _composer.removeListener(_composerEdited);
    _historyScroll.dispose();
    _composer.dispose();
    _presentation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildChat(context);
}

int _compareMessages(CommunityMessage left, CommunityMessage right) {
  final time = left.createdAt.compareTo(right.createdAt);
  return time == 0 ? left.id.compareTo(right.id) : time;
}

List<CommunityMessage> _mergeMessages(Iterable<CommunityMessage> messages) {
  final byId = {for (final message in messages) message.id: message};
  final rows = byId.values.toList()..sort(_compareMessages);
  return List.unmodifiable(rows);
}

String _messageLimitText(BuildContext context) => communityText(
  context,
  'Keep the message within 2000 characters. Your text is kept.',
  'اجعل الرسالة في حدود 2000 حرف. احتفظنا بالنص كاملًا.',
);

String _copy(
  BuildContext context,
  String ar,
  String en,
  String fr,
  String es,
  String tr,
) {
  final localeTag = BilLocalePolicy.canonicalTag(
    Localizations.localeOf(context),
  );
  return switch (Localizations.localeOf(context).languageCode) {
    'ar' => ar,
    'fr' => fr,
    'es' => es,
    'tr' => tr,
    _ =>
      CommunityChatRuntimeCopy.resolve(en, localeTag) ??
          RuntimeCopy.resolve(en, localeTag) ??
          en,
  };
}
