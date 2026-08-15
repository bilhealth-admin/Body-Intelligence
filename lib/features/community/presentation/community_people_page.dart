import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/runtime_copy.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import '../services/contact_picker_service.dart';

class CommunityPeoplePage extends StatefulWidget {
  const CommunityPeoplePage({this.repository, super.key});
  final CommunityRepository? repository;
  @override
  State<CommunityPeoplePage> createState() => _CommunityPeoplePageState();
}

class _CommunityPeoplePageState extends State<CommunityPeoplePage> {
  CommunityRepository? _repository;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Future<List<Map<String, dynamic>>> _results = Future.value(const []);
  final Set<String> _pendingRequests = <String>{};
  bool _pickingContact = false;
  String _lastQuery = '';

  Future<void> _pickContact() async {
    if (_pickingContact) return;
    setState(() => _pickingContact = true);
    try {
      final contact = await const ContactPickerService().pick();
      if (!mounted || contact == null) return;
      final query = contact.name.trim();
      if (query.isNotEmpty) {
        _search.text = query;
        _search.selection = TextSelection.collapsed(offset: query.length);
        _searchPeople(query);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'تم اختيار جهة الاتصال محليًا. سنبحث باسمها في BIL من دون رفع دفتر عناوينك.',
              'Contact selected locally. BIL will search by name without uploading your address book.',
              'Contact sélectionné localement. BIL recherche son nom sans importer votre carnet.',
              'Contacto seleccionado localmente. BIL buscará el nombre sin subir tu agenda.',
              'Kişi yerel olarak seçildi. BIL rehberinizi yüklemeden adla arama yapar.',
            ),
          ),
        ),
      );
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'تعذر فتح منتقي جهات الاتصال الآمن.',
              'The secure contact picker could not be opened.',
              'Impossible d’ouvrir le sélecteur de contacts sécurisé.',
              'No se pudo abrir el selector seguro de contactos.',
              'Güvenli kişi seçici açılamadı.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingContact = false);
    }
  }

  void _searchPeople(String value) {
    final repository = _repository;
    if (repository == null) return;
    _lastQuery = value;
    final results = repository.searchProfiles(value);
    setState(() {
      _results = results;
    });
  }

  Future<void> _requestFriend(String userId) async {
    final repository = _repository;
    if (repository == null) return;
    if (_pendingRequests.contains(userId)) return;
    setState(() => _pendingRequests.add(userId));
    try {
      await repository.requestFriend(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'تم إرسال الطلب.',
              'Request sent.',
              'Demande envoyée.',
              'Solicitud enviada.',
              'İstek gönderildi.',
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
              'تعذر إرسال الطلب بأمان. حاول مجددًا.',
              'Could not send the request safely. Try again.',
              'Impossible d’envoyer la demande. Réessayez.',
              'No se pudo enviar la solicitud. Inténtalo de nuevo.',
              'İstek gönderilemedi. Tekrar deneyin.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pendingRequests.remove(userId));
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository;
      _results = _repository!.searchProfiles('');
      return;
    }
    if (!AppEnvironment.cloudConfigured) return;
    try {
      final supabase = Supabase.instance;
      if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
        return;
      }
      _repository = CommunityRepository(supabase.client);
      _results = _repository!.searchProfiles('');
    } on AssertionError {
      return;
    } on StateError {
      return;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _copy(
          context,
          'البحث عن أصدقاء',
          'Find people',
          'Trouver des amis',
          'Buscar personas',
          'Kişileri bul',
        ),
      ),
    ),
    body: _repository == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('community-add-from-contacts'),
                          onPressed: null,
                          icon: const Icon(Icons.contacts_outlined),
                          label: Text(
                            _copy(
                              context,
                              'جهات الاتصال',
                              'Contacts',
                              'Contacts',
                              'Contactos',
                              'Kişiler',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('community-add-by-bil-name'),
                          onPressed: null,
                          icon: const Icon(Icons.alternate_email_rounded),
                          label: Text(
                            _copy(
                              context,
                              'اسم BIL',
                              'BIL name',
                              'Nom BIL',
                              'Nombre BIL',
                              'BIL adı',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _copy(
                      context,
                      'سجّل الدخول وفعّل السحابة للبحث عن الأصدقاء.',
                      'Sign in and enable cloud access to find people.',
                      'Connectez-vous et activez le cloud pour trouver des amis.',
                      'Inicia sesión y activa la nube para buscar personas.',
                      'Kişileri bulmak için oturum açın ve bulutu etkinleştirin.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('community-add-from-contacts'),
                        onPressed: _pickingContact ? null : _pickContact,
                        icon: _pickingContact
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.contacts_outlined),
                        label: Text(
                          _copy(
                            context,
                            'جهات الاتصال',
                            'Contacts',
                            'Contacts',
                            'Contactos',
                            'Kişiler',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('community-add-by-bil-name'),
                        onPressed: () => _searchFocus.requestFocus(),
                        icon: const Icon(Icons.alternate_email_rounded),
                        label: Text(
                          _copy(
                            context,
                            'اسم BIL',
                            'BIL name',
                            'Nom BIL',
                            'Nombre BIL',
                            'BIL adı',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  key: const Key('community-people-search'),
                  focusNode: _searchFocus,
                  controller: _search,
                  onChanged: _searchPeople,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: _copy(
                      context,
                      'الاسم',
                      'Display name',
                      'Nom',
                      'Nombre',
                      'Ad',
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _results,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _copy(
                                context,
                                'تعذر البحث الآن. حاول مجددًا.',
                                'Search is unavailable right now. Try again.',
                                'La recherche est indisponible. Réessayez.',
                                'La búsqueda no está disponible. Inténtalo de nuevo.',
                                'Arama şu anda kullanılamıyor. Tekrar deneyin.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => _searchPeople(_lastQuery),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(
                                _copy(
                                  context,
                                  'إعادة المحاولة',
                                  'Retry',
                                  'Réessayer',
                                  'Reintentar',
                                  'Tekrar dene',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final rows = snapshot.data ?? const [];
                    if (rows.isEmpty) {
                      return Center(
                        child: Text(
                          _copy(
                            context,
                            'لا توجد نتائج.',
                            'No people found.',
                            'Aucun résultat.',
                            'Sin resultados.',
                            'Sonuç yok.',
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: row['avatar_url'] == null
                                ? null
                                : NetworkImage(row['avatar_url'] as String),
                            child: row['avatar_url'] == null
                                ? const Icon(Icons.person_rounded)
                                : null,
                          ),
                          title: Text(row['display_name'] as String),
                          subtitle: row['bio'] == null
                              ? null
                              : Text(
                                  row['bio'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: IconButton(
                            tooltip: _copy(
                              context,
                              'إرسال طلب',
                              'Send request',
                              'Envoyer',
                              'Enviar',
                              'İstek gönder',
                            ),
                            icon: _pendingRequests.contains(row['user_id'])
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.person_add_alt_1_rounded),
                            onPressed: _pendingRequests.contains(row['user_id'])
                                ? null
                                : () =>
                                      _requestFriend(row['user_id'] as String),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
  );
}

class CommunityChatPage extends StatefulWidget {
  const CommunityChatPage({
    super.key,
    required this.userId,
    required this.displayName,
  });
  final String userId, displayName;
  @override
  State<CommunityChatPage> createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends State<CommunityChatPage> {
  CommunityRepository? _repository;
  final _composer = TextEditingController();
  Future<List<CommunityMessage>> _messages = Future.value(const []);
  bool _sending = false;
  @override
  void initState() {
    super.initState();
    if (!AppEnvironment.cloudConfigured) return;
    try {
      final supabase = Supabase.instance;
      if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
        return;
      }
      _repository = CommunityRepository(supabase.client);
      _messages = _loadConversation();
    } on AssertionError {
      return;
    } on StateError {
      return;
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
) => switch (Localizations.localeOf(context).languageCode) {
  'ar' => ar,
  'fr' => fr,
  'es' => es,
  'tr' => tr,
  final language => RuntimeCopy.resolve(en, language) ?? en,
};
