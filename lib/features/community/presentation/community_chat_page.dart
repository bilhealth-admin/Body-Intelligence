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
  final _historyScroll = ScrollController(keepScrollOffset: false);
  Future<List<CommunityMessage>> _messages = Future.value(const []);
  StreamSubscription<void>? _conversationChanges;
  TextDirection? _composerDirection;
  bool _sending = false;
  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository;
      _messages = _loadConversation();
      _watchConversation();
      return;
    }
    if (!AppEnvironment.communityConfigured) return;
    try {
      final supabase = Supabase.instance;
      if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
        return;
      }
      _repository = CommunityRepository(supabase.client);
      _messages = _loadConversation();
      _watchConversation();
    } on AssertionError {
      return;
    } on StateError {
      return;
    }
  }

  void _watchConversation() {
    try {
      _conversationChanges = _repository
          ?.watchConversationChanges(widget.userId)
          .listen((_) {
            if (mounted) setState(_reload);
          }, onError: (_) {});
    } on AuthException {
      _conversationChanges = null;
    } on ArgumentError {
      _conversationChanges = null;
    }
  }

  Future<List<CommunityMessage>> _loadConversation() async {
    final messages = await _repository!.loadMessages(widget.userId);
    await _repository!.markConversationRead(widget.userId);
    return messages;
  }

  void _reload() {
    _messages = _loadConversation();
  }

  void _updateComposerDirection(String value) {
    final direction = BilWrittenLanguageResolver.directionFor(
      value,
      fallback: Directionality.of(context),
    );
    if (direction != _composerDirection) {
      setState(() => _composerDirection = direction);
    }
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    // Sending is an explicit request to follow the conversation end. Do this
    // now, not after the async reply when the user might be reading history.
    if (_historyScroll.hasClients) {
      _historyScroll.jumpTo(_historyScroll.position.minScrollExtent);
    }
    try {
      await _repository!.sendMessage(widget.userId, body);
      if (!mounted) return;
      if (_composer.text.trim() == body) _composer.clear();
      setState(_reload);
    } on CommunityPolicyAccessException catch (error) {
      if (!mounted) return;
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
              context.push('/community/safety');
            },
          ),
        ),
      );
    } on CommunityMembershipAccessException catch (error) {
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    unawaited(_conversationChanges?.cancel());
    _historyScroll.dispose();
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.displayName)),
    body: _repository == null
        ? Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_chat_unread_outlined, size: 52),
                      const SizedBox(height: 16),
                      Text(
                        _copy(
                          context,
                          'سجّل الدخول لفتح الرسائل.',
                          'Sign in to open messages.',
                          'Connectez-vous pour ouvrir les messages.',
                          'Inicia sesión para abrir los mensajes.',
                          'Mesajları açmak için giriş yapın.',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _copy(
                          context,
                          'لا تظهر بياناتك الصحية داخل الرسائل.',
                          'Your health data is never shown in messages.',
                          'Vos données de santé ne figurent jamais dans les messages.',
                          'Tus datos de salud nunca aparecen en los mensajes.',
                          'Sağlık verileriniz mesajlarda gösterilmez.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : Column(
            children: [
              Expanded(
                child: FutureBuilder<List<CommunityMessage>>(
                  future: _messages,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: FilledButton.tonalIcon(
                          onPressed: () => setState(_reload),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            _copy(
                              context,
                              'تعذر تحميل المحادثة. أعد المحاولة.',
                              'Could not load this chat. Try again.',
                              'Conversation indisponible. Réessayez.',
                              'No se pudo cargar el chat. Inténtalo de nuevo.',
                              'Sohbet yüklenemedi. Tekrar deneyin.',
                            ),
                          ),
                        ),
                      );
                    }
                    final rows = snapshot.data ?? const [];
                    return ChatHistoryViewport(
                      controller: _historyScroll,
                      latestMessageId: rows.isEmpty ? null : rows.last.id,
                      child: RefreshIndicator(
                        onRefresh: () async {
                          setState(_reload);
                          await _messages;
                        },
                        child: ListView.builder(
                          key: const Key('community-message-history'),
                          controller: _historyScroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          findChildIndexCallback: (key) {
                            if (key is! ValueKey<String>) return null;
                            final position = rows.indexWhere(
                              (message) => message.id == key.value,
                            );
                            return position < 0
                                ? null
                                : rows.length - 1 - position;
                          },
                          physics: const AlwaysScrollableScrollPhysics(),
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final message = rows[rows.length - 1 - index];
                            final mine =
                                message.senderId == _repository!.currentUserId;
                            return Align(
                              key: ValueKey(message.id),
                              alignment: mine
                                  ? AlignmentDirectional.centerEnd
                                  : AlignmentDirectional.centerStart,
                              child: Card(
                                color: mine
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      SelectableText(
                                        message.body,
                                        textDirection:
                                            BilWrittenLanguageResolver.directionFor(
                                              message.body,
                                              fallback: Directionality.of(
                                                context,
                                              ),
                                            ),
                                        key: ValueKey(
                                          'community-message-text-${message.id}',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            TimeOfDay.fromDateTime(
                                              message.createdAt.toLocal(),
                                            ).format(context),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                          if (mine) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              message.isRead
                                                  ? Icons.done_all_rounded
                                                  : Icons.done_rounded,
                                              size: 15,
                                              semanticLabel: message.isRead
                                                  ? _copy(
                                                      context,
                                                      'مقروءة',
                                                      'Read',
                                                      'Lu',
                                                      'Leído',
                                                      'Okundu',
                                                    )
                                                  : _copy(
                                                      context,
                                                      'مُرسلة',
                                                      'Sent',
                                                      'Envoyé',
                                                      'Enviado',
                                                      'Gönderildi',
                                                    ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('community-message-composer'),
                          controller: _composer,
                          minLines: 1,
                          maxLines: 4,
                          textDirection:
                              _composerDirection ?? Directionality.of(context),
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 2000,
                          onChanged: _updateComposerDirection,
                          decoration: InputDecoration(
                            hintText: _copy(
                              context,
                              'رسالة',
                              'Message',
                              'Message',
                              'Mensaje',
                              'Mesaj',
                            ),
                            counterText: '',
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: _copy(
                          context,
                          'إرسال الرسالة',
                          'Send message',
                          'Envoyer le message',
                          'Enviar mensaje',
                          'Mesaj gönder',
                        ),
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}

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
