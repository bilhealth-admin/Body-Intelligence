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
  Future<List<CommunityMessage>> _messages = Future.value(const []);
  StreamSubscription<void>? _conversationChanges;
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
    if (!AppEnvironment.cloudConfigured) return;
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

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repository!.sendMessage(widget.userId, body);
      _composer.clear();
      if (mounted) setState(_reload);
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
                    if (snapshot.connectionState != ConnectionState.done) {
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
                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(_reload);
                        await _messages;
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final message = rows[rows.length - 1 - index];
                          final mine =
                              message.senderId == _repository!.currentUserId;
                          return Align(
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
                                    Text(message.body),
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
                          controller: _composer,
                          maxLength: 2000,
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
    _ => RuntimeCopy.resolve(en, localeTag) ?? en,
  };
}
