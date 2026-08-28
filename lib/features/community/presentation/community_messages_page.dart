import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../data/community_repository.dart';
import '../domain/community_text_policy.dart';

SupabaseClient? _initializedCommunityClient() {
  if (!AppEnvironment.cloudConfigured) return null;
  try {
    final supabase = Supabase.instance;
    return supabase.isInitialized ? supabase.client : null;
  } on AssertionError {
    return null;
  } on StateError {
    return null;
  }
}

class CommunityMessagesPage extends StatefulWidget {
  const CommunityMessagesPage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<CommunityMessagesPage> createState() => _CommunityMessagesPageState();
}

class _CommunityMessagesPageState extends State<CommunityMessagesPage> {
  CommunityRepository? _repository;
  late Future<List<Map<String, dynamic>>> _inbox;
  late Future<List<Map<String, dynamic>>> _sent;
  StreamSubscription<void>? _inboxChanges;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository;
      _reload();
      _watchInbox();
      return;
    }
    final client = _initializedCommunityClient();
    if (client?.auth.currentUser != null) {
      _repository = CommunityRepository(client!);
    }
    _reload();
    _watchInbox();
  }

  void _watchInbox() {
    try {
      _inboxChanges = _repository?.watchInboxChanges().listen((_) {
        if (mounted) unawaited(_refreshInbox());
      }, onError: (_) {});
    } on AuthException {
      // The injected repository may outlive its signed-in test/session user.
      // The already-loaded inbox remains usable without a realtime channel.
      _inboxChanges = null;
    }
  }

  @override
  void dispose() {
    unawaited(_inboxChanges?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    _inbox = _repository?.loadInboxMessages() ?? Future.value(const []);
    _sent = _repository?.loadSentMessages() ?? Future.value(const []);
    await Future.wait([_inbox, _sent]);
  }

  Future<void> _refresh() async {
    setState(() {
      _inbox = _repository!.loadInboxMessages();
      _sent = _repository!.loadSentMessages();
    });
    await Future.wait([_inbox, _sent]);
  }

  Future<void> _refreshInbox() async {
    setState(() {
      _inbox = _repository!.loadInboxMessages();
    });
    await _inbox;
  }

  Future<void> _refreshSent() async {
    setState(() {
      _sent = _repository!.loadSentMessages();
    });
    await _sent;
  }

  @override
  Widget build(BuildContext context) {
    final copy = _MessagesCopy.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(copy.messages),
          actions: [
            IconButton(
              tooltip: copy.newMessage,
              icon: const Icon(Icons.add_rounded),
              onPressed: _repository == null
                  ? null
                  : () async {
                      await context.push('/community/messages/new');
                      if (mounted) await _refresh();
                    },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: copy.inbox),
              Tab(text: copy.sent),
            ],
          ),
        ),
        body: _repository == null
            ? _MessagesSignIn(copy: copy)
            : TabBarView(
                children: [
                  _MessageList(
                    future: _inbox,
                    emptyText: copy.noMessages,
                    copy: copy,
                    incoming: true,
                    onRetry: _refreshInbox,
                  ),
                  _MessageList(
                    future: _sent,
                    emptyText: copy.noSentMessages,
                    copy: copy,
                    incoming: false,
                    onRetry: _refreshSent,
                  ),
                ],
              ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.future,
    required this.emptyText,
    required this.copy,
    required this.incoming,
    required this.onRetry,
  });
  final Future<List<Map<String, dynamic>>> future;
  final String emptyText;
  final _MessagesCopy copy;
  final bool incoming;
  final Future<void> Function() onRetry;

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _MessagesLoadError(copy: copy, onRetry: onRetry);
      }
      final rows = snapshot.data ?? const [];
      return RefreshIndicator(
        onRefresh: onRetry,
        child: rows.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _EmptyMessages(text: emptyText, button: copy.sendMessage),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final profile = row['profile'] as Map<String, dynamic>?;
                  final parsed = MessageBodyContract.parse(
                    row['body'] as String,
                  );
                  final otherId =
                      (incoming ? row['sender_id'] : row['recipient_id'])
                          as String;
                  final name =
                      profile?['display_name'] as String? ?? copy.unknownMember;
                  return ListTile(
                    leading: BilAccountAvatar(
                      radius: 20,
                      networkUrl: profile?['avatar_url'] as String?,
                    ),
                    title: _NaturalMessageText(
                      parsed.subject.isEmpty ? name : parsed.subject,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NaturalMessageText(name, maxLines: 1),
                        _NaturalMessageText(parsed.body, maxLines: 2),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(
                      '/community/chat/$otherId?name=${Uri.encodeQueryComponent(name)}',
                    ),
                  );
                },
              ),
      );
    },
  );
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages({required this.text, required this.button});
  final String text, button;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        const SizedBox(height: 64),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.push('/community/messages/new'),
            child: Text(button),
          ),
        ),
      ],
    ),
  );
}

class _NaturalMessageText extends StatelessWidget {
  const _NaturalMessageText(this.text, {this.maxLines});
  final String text;
  final int? maxLines;
  @override
  Widget build(BuildContext context) {
    final direction = RegExp(r'[\u0600-\u08ff]').hasMatch(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        textAlign: TextAlign.start,
      ),
    );
  }
}

class _MessagesSignIn extends StatelessWidget {
  const _MessagesSignIn({required this.copy});
  final _MessagesCopy copy;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_person_outlined, size: 54),
          const SizedBox(height: 12),
          Text(copy.signInRequired, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/login'),
            icon: const Icon(Icons.login_rounded),
            label: Text(copy.signIn),
          ),
        ],
      ),
    ),
  );
}

class _MessagesLoadError extends StatelessWidget {
  const _MessagesLoadError({required this.copy, required this.onRetry});
  final _MessagesCopy copy;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 52),
          const SizedBox(height: 12),
          Text(copy.loadFailed, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(copy.retry),
          ),
        ],
      ),
    ),
  );
}

class NewCommunityMessagePage extends StatefulWidget {
  const NewCommunityMessagePage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<NewCommunityMessagePage> createState() =>
      _NewCommunityMessagePageState();
}

class _NewCommunityMessagePageState extends State<NewCommunityMessagePage> {
  final _recipientSearch = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  CommunityRepository? _repository;
  Timer? _debounce;
  Future<List<Map<String, dynamic>>> _people = Future.value(const []);
  int _searchGeneration = 0;
  Map<String, dynamic>? _recipient;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository;
      _people = _repository!.searchProfiles('');
      return;
    }
    final client = _initializedCommunityClient();
    if (client?.auth.currentUser != null) {
      _repository = CommunityRepository(client!);
      _people = _repository!.searchProfiles('');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recipientSearch.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _repository != null) {
        setState(() {
          _people = _repository!
              .searchProfiles(value)
              .then(
                (rows) => generation == _searchGeneration ? rows : const [],
              );
        });
      }
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    final copy = _MessagesCopy.of(context);
    if (_repository == null ||
        _recipient == null ||
        _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.completeFields)));
      return;
    }
    setState(() => _sending = true);
    try {
      await _repository!.sendMessage(
        _recipient!['user_id'] as String,
        MessageBodyContract.compose(subject: _subject.text, body: _body.text),
      );
      if (mounted) context.pop();
    } on CommunityTextPolicyException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.localizedMessage(
                Localizations.localeOf(context).toLanguageTag(),
              ),
            ),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.sendFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _MessagesCopy.of(context);
    if (_repository == null) {
      return Scaffold(
        appBar: AppBar(title: Text(copy.newMessage)),
        body: _MessagesSignIn(copy: copy),
      );
    }
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _sending ? null : () => context.pop(),
          ),
          title: Text(copy.newMessage),
          actions: [
            IconButton(
              icon: const Icon(Icons.check_rounded),
              tooltip: copy.send,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
        body: Column(
          children: [
            if (_sending) const LinearProgressIndicator(),
            if (_recipient == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  key: const Key('community-message-recipient-search'),
                  controller: _recipientSearch,
                  autofocus: true,
                  enabled: !_sending,
                  onChanged: _search,
                  decoration: InputDecoration(
                    labelText: copy.to,
                    prefixIcon: const Icon(Icons.person_search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                  ),
                ),
              )
            else
              Card(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: ListTile(
                  leading: BilAccountAvatar(
                    radius: 20,
                    networkUrl: _recipient!['avatar_url'] as String?,
                  ),
                  title: Text(_recipient!['display_name'] as String),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _sending
                        ? null
                        : () => setState(() => _recipient = null),
                  ),
                ),
              ),
            if (_recipient == null)
              SizedBox(
                height: 180,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _people,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _PeopleSearchError(
                        copy: copy,
                        onRetry: () => _search(_recipientSearch.text),
                      );
                    }
                    return ListView(
                      children: [
                        for (final person
                            in snapshot.data ?? const <Map<String, dynamic>>[])
                          ListTile(
                            leading: BilAccountAvatar(
                              radius: 20,
                              networkUrl: person['avatar_url'] as String?,
                            ),
                            title: Text(person['display_name'] as String),
                            onTap: _sending
                                ? null
                                : () => setState(() => _recipient = person),
                          ),
                      ],
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _subject,
                enabled: !_sending,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                decoration: InputDecoration(
                  labelText: copy.subject,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _body,
                  enabled: !_sending,
                  inputFormatters: [LengthLimitingTextInputFormatter(4000)],
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: copy.message,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBodyContract {
  static const marker = '[BIL-SUBJECT]';
  static String compose({required String subject, required String body}) {
    final cleanBody = body.trim();
    final cleanSubject = subject.trim().replaceAll(RegExp(r'[\r\n]+'), ' ');
    return cleanSubject.isEmpty
        ? cleanBody
        : '$marker$cleanSubject\n$cleanBody';
  }

  static ({String subject, String body}) parse(String value) {
    if (value.trim().isEmpty ||
        value.length > 4200 ||
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(value)) {
      throw const FormatException('Invalid stored message body');
    }
    if (!value.startsWith(marker)) return (subject: '', body: value);
    final newline = value.indexOf('\n');
    if (newline < 0) throw const FormatException('Invalid subject envelope');
    final subject = value.substring(marker.length, newline);
    final body = value.substring(newline + 1);
    if (subject.length > 120 || body.trim().isEmpty || body.length > 4000) {
      throw const FormatException('Invalid subject envelope');
    }
    return (subject: subject, body: body);
  }
}

class _PeopleSearchError extends StatelessWidget {
  const _PeopleSearchError({required this.copy, required this.onRetry});
  final _MessagesCopy copy;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: Text(copy.retry),
    ),
  );
}

class _MessagesCopy {
  const _MessagesCopy(this.v);
  final Map<String, String> v;
  String get messages => v['messages']!;
  String get inbox => v['inbox']!;
  String get sent => v['sent']!;
  String get noMessages => v['noMessages']!;
  String get noSentMessages => v['noSentMessages']!;
  String get sendMessage => v['sendMessage']!;
  String get newMessage => v['newMessage']!;
  String get to => v['to']!;
  String get subject => v['subject']!;
  String get message => v['message']!;
  String get send => v['send']!;
  String get loadFailed => v['loadFailed']!;
  String get sendFailed => v['sendFailed']!;
  String get completeFields => v['completeFields']!;
  String get unknownMember => v['unknownMember']!;
  String get signInRequired => v['signInRequired']!;
  String get signIn => v['signIn']!;
  String get retry => v['retry']!;
  static _MessagesCopy of(BuildContext context) => _MessagesCopy(
    _catalog[Localizations.localeOf(context).languageCode] ??
        _extended(context),
  );

  static Map<String, String> _extended(BuildContext context) {
    String t(String value) => AppLocalizations.of(context).text(value);
    return {
      for (final entry in _catalog['en']!.entries) entry.key: t(entry.value),
    };
  }

  static const _catalog = <String, Map<String, String>>{
    'en': {
      'messages': 'Messages',
      'inbox': 'Inbox',
      'sent': 'Sent',
      'noMessages': 'No messages',
      'noSentMessages': 'No sent messages',
      'sendMessage': 'Send a message',
      'newMessage': 'New message',
      'to': 'To: user name',
      'subject': 'Subject',
      'message': 'Message',
      'send': 'Send',
      'loadFailed': 'Messages could not be loaded safely.',
      'sendFailed': 'Message could not be sent.',
      'completeFields': 'Choose a recipient and enter a message.',
      'unknownMember': 'BIL member',
      'signInRequired': 'Sign in to view and send messages.',
      'signIn': 'Sign in',
      'retry': 'Retry',
    },
    'ar': {
      'messages': 'الرسائل',
      'inbox': 'الوارد',
      'sent': 'المرسلة',
      'noMessages': 'لا توجد رسائل',
      'noSentMessages': 'لا توجد رسائل مرسلة',
      'sendMessage': 'إرسال رسالة',
      'newMessage': 'رسالة جديدة',
      'to': 'إلى: اسم المستخدم',
      'subject': 'الموضوع',
      'message': 'الرسالة',
      'send': 'إرسال',
      'loadFailed': 'تعذر تحميل الرسائل بأمان.',
      'sendFailed': 'تعذر إرسال الرسالة.',
      'completeFields': 'اختر مستلمًا واكتب رسالة.',
      'unknownMember': 'عضو BIL',
      'signInRequired': 'سجّل الدخول لعرض الرسائل وإرسالها.',
      'signIn': 'تسجيل الدخول',
      'retry': 'إعادة المحاولة',
    },
    'fr': {
      'messages': 'Messages',
      'inbox': 'Boîte de réception',
      'sent': 'Envoyés',
      'noMessages': 'Aucun message',
      'noSentMessages': 'Aucun message envoyé',
      'sendMessage': 'Envoyer un message',
      'newMessage': 'Nouveau message',
      'to': 'À : nom d’utilisateur',
      'subject': 'Objet',
      'message': 'Message',
      'send': 'Envoyer',
      'loadFailed': 'Impossible de charger les messages en toute sécurité.',
      'sendFailed': 'Le message n’a pas pu être envoyé.',
      'completeFields': 'Choisissez un destinataire et saisissez un message.',
      'unknownMember': 'Membre BIL',
      'signInRequired': 'Connectez-vous pour voir et envoyer des messages.',
      'signIn': 'Se connecter',
      'retry': 'Réessayer',
    },
    'es': {
      'messages': 'Mensajes',
      'inbox': 'Recibidos',
      'sent': 'Enviados',
      'noMessages': 'No hay mensajes',
      'noSentMessages': 'No hay mensajes enviados',
      'sendMessage': 'Enviar un mensaje',
      'newMessage': 'Nuevo mensaje',
      'to': 'Para: nombre de usuario',
      'subject': 'Asunto',
      'message': 'Mensaje',
      'send': 'Enviar',
      'loadFailed': 'No se pudieron cargar los mensajes de forma segura.',
      'sendFailed': 'No se pudo enviar el mensaje.',
      'completeFields': 'Elige un destinatario y escribe un mensaje.',
      'unknownMember': 'Miembro de BIL',
      'signInRequired': 'Inicia sesión para ver y enviar mensajes.',
      'signIn': 'Iniciar sesión',
      'retry': 'Reintentar',
    },
    'tr': {
      'messages': 'Mesajlar',
      'inbox': 'Gelen kutusu',
      'sent': 'Gönderilenler',
      'noMessages': 'Mesaj yok',
      'noSentMessages': 'Gönderilmiş mesaj yok',
      'sendMessage': 'Mesaj gönder',
      'newMessage': 'Yeni mesaj',
      'to': 'Kime: kullanıcı adı',
      'subject': 'Konu',
      'message': 'Mesaj',
      'send': 'Gönder',
      'loadFailed': 'Mesajlar güvenle yüklenemedi.',
      'sendFailed': 'Mesaj gönderilemedi.',
      'completeFields': 'Bir alıcı seçin ve mesaj yazın.',
      'unknownMember': 'BIL üyesi',
      'signInRequired': 'Mesajları görmek ve göndermek için oturum açın.',
      'signIn': 'Oturum aç',
      'retry': 'Tekrar dene',
    },
  };
}
