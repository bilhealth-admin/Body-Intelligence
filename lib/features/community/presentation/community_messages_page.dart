import '../../../app/localization/bil_written_language_resolver.dart';
import 'community_attention_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../data/community_repository.dart';
import '../domain/community_content_policy.dart';
import '../domain/community_text_policy.dart';
import '../services/community_owner_operation.dart';
import 'community_return_button.dart';
import 'community_copy.dart';
import 'community_sapphire.dart';
import 'community_policy_notice.dart';
import 'community_safety_page.dart';

part 'community_messages_copy.dart';
part 'community_message_owner_scope.dart';
part 'community_conversation_tile.dart';
part 'new_community_message_page.dart';

SupabaseClient? _initializedCommunityClient() {
  if (!AppEnvironment.communityConfigured) return null;
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
  _MessageOwnerVisit? _visit;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _visit = null;
    _repository = widget.repository;
    final client = _initializedCommunityClient();
    if (_repository == null && client?.auth.currentUser != null) {
      _repository = CommunityRepository(client!);
    }
    final repository = _repository;
    if (repository != null) {
      _visit = _MessageOwnerVisit(repository, () => mounted, () {
        unawaited(_inboxChanges?.cancel());
        _inboxChanges = null;
        if (mounted) setState(() {});
      });
    }
    _reload();
    _watchInbox();
  }

  @override
  void didUpdateWidget(covariant CommunityMessagesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _visit?.dispose();
      unawaited(_inboxChanges?.cancel());
      _inboxChanges = null;
      _bind();
    }
  }

  void _watchInbox() {
    final visit = _visit;
    if (visit?.isCurrent != true) return;
    try {
      _inboxChanges = visit!.repository.watchInboxChanges().listen((_) {
        if (visit.isCurrent) unawaited(_refreshInbox());
      }, onError: (Object _, StackTrace _) {});
    } on AuthException {
      _inboxChanges = null;
    }
  }

  @override
  void dispose() {
    _visit?.dispose();
    unawaited(_inboxChanges?.cancel());
    super.dispose();
  }

  void _reload() {
    final visit = _visit;
    _inbox = visit?.isCurrent == true
        ? visit!.run(visit.repository.loadInboxMessages)
        : Future.value(const []);
    _sent = visit?.isCurrent == true
        ? visit!.run(visit.repository.loadSentMessages)
        : Future.value(const []);
    // A not-yet-opened tab may not have a FutureBuilder attached. Observe its
    // error without changing the original future or hiding its retry state.
    _inbox.ignore();
    _sent.ignore();
  }

  Future<void> _refresh() async {
    final visit = _visit;
    if (visit?.isCurrent != true) return;
    setState(_reload);
    try {
      await Future.wait([_inbox, _sent]);
    } on Object {
      /* Visible retry owns the failure. */
    }
  }

  Future<void> _refreshInbox() async {
    final visit = _visit;
    if (visit?.isCurrent != true) return;
    setState(() {
      _inbox = visit!.run(visit.repository.loadInboxMessages);
    });
    try {
      await _inbox;
    } on Object {
      /* Visible retry owns the failure. */
    }
  }

  Future<void> _refreshSent() async {
    final visit = _visit;
    if (visit?.isCurrent != true) return;
    setState(() {
      _sent = visit!.run(visit.repository.loadSentMessages);
    });
    try {
      await _sent;
    } on Object {
      /* Visible retry owns the failure. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _MessagesCopy.of(context);
    final visit = _visit;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const CommunityReturnButton(),
          title: Text(copy.messages),
          actions: [
            IconButton(
              tooltip: copy.newMessage,
              icon: const Icon(Icons.add_rounded),
              onPressed: visit?.isCurrent != true
                  ? null
                  : () async {
                      if (!visit!.isCurrent) return;
                      await context.push('/community/messages/new');
                      if (mounted && visit.isCurrent) await _refresh();
                    },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        copy.inbox,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const CommunityUnreadBadge(
                      kind: CommunityAttentionKind.messages,
                    ),
                  ],
                ),
              ),
              Tab(text: copy.sent),
            ],
          ),
        ),
        body: visit != null && !visit.isCurrent
            ? const _MessageOwnerChanged()
            : _repository == null
            ? _MessagesSignIn(copy: copy)
            : TabBarView(
                key: ObjectKey(visit),
                children: [
                  _MessageList(
                    visit: visit!,
                    future: _inbox,
                    emptyText: copy.noMessages,
                    copy: copy,
                    incoming: true,
                    onRetry: _refreshInbox,
                  ),
                  _MessageList(
                    visit: visit,
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
    required this.visit,
    required this.emptyText,
    required this.copy,
    required this.incoming,
    required this.onRetry,
  });
  final Future<List<Map<String, dynamic>>> future;
  final _MessageOwnerVisit visit;
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
      if (snapshot.connectionState != ConnectionState.done &&
          !snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _MessagesLoadError(copy: copy, onRetry: onRetry);
      }
      final rawRows = snapshot.data ?? const <Map<String, dynamic>>[];
      final rows = communityThreadPreviewRows(rawRows, incoming: incoming);
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                  final attention = CommunityAttentionScope.controllerOf(
                    context,
                  );
                  final unreadCount = incoming
                      ? communityThreadUnreadCount(
                          otherId,
                          rawRows,
                          authoritative: attention?.hasSnapshot == true
                              ? attention!.value.unreadBySender
                              : null,
                        )
                      : 0;
                  final createdAt = DateTime.tryParse(
                    row['created_at'] as String? ?? '',
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      color: CommunitySapphire.paper(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _CommunityConversationTile(
                        key: ValueKey('community-inbox-${row['id']}'),
                        title: parsed.subject.isEmpty ? name : parsed.subject,
                        authorName: parsed.subject.isNotEmpty ? name : null,
                        body: parsed.body,
                        avatarUrl: profile?['avatar_url'] as String?,
                        createdAt: createdAt,
                        unreadCount: unreadCount,
                        onTap: () async {
                          if (!visit.isCurrent) return;
                          await context.push(
                            '/community/chat/$otherId?name=${Uri.encodeQueryComponent(name)}',
                          );
                          if (context.mounted && visit.isCurrent) {
                            await onRetry();
                            if (context.mounted && visit.isCurrent) {
                              await CommunityAttentionScope.refresh(context);
                            }
                          }
                        },
                      ),
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
        const SizedBox(height: 48),
        const ExcludeSemantics(
          child: Text('💬', style: TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 16),
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
  const _NaturalMessageText(this.text, {this.maxLines, this.style});
  final String text;
  final int? maxLines;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final direction = BilWrittenLanguageResolver.directionFor(
      text,
      fallback: Directionality.of(context),
    );
    return Directionality(
      textDirection: direction,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: style,
        textAlign: Directionality.of(context) == TextDirection.rtl
            ? TextAlign.right
            : TextAlign.left,
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
        value.runes.length > 2000 ||
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(value)) {
      throw const FormatException('Invalid stored message body');
    }
    if (!value.startsWith(marker)) return (subject: '', body: value);
    final newline = value.indexOf('\n');
    if (newline < 0) throw const FormatException('Invalid subject envelope');
    final subject = value.substring(marker.length, newline);
    final body = value.substring(newline + 1);
    if (subject.runes.length > 120 ||
        body.trim().isEmpty ||
        body.runes.length > 2000) {
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
