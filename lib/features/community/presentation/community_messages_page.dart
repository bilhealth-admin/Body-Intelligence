import '../../../app/localization/bil_written_language_resolver.dart';
import 'community_attention_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../data/community_repository.dart';
import '../domain/community_content_policy.dart';
import '../domain/community_text_policy.dart';
import 'community_copy.dart';
import 'community_sapphire.dart';
import 'community_policy_notice.dart';
import 'community_safety_page.dart';

part 'community_messages_copy.dart';
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
                  final unread = unreadCount > 0;
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
                      child: ListTile(
                        key: ValueKey('community-inbox-${row['id']}'),
                        minTileHeight: 88,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        tileColor: unread
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: .25)
                            : null,
                        leading: BilAccountAvatar(
                          radius: 24,
                          networkUrl: profile?['avatar_url'] as String?,
                        ),
                        title: _NaturalMessageText(
                          parsed.subject.isEmpty ? name : parsed.subject,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (parsed.subject.isNotEmpty)
                              _NaturalMessageText(name, maxLines: 1),
                            _NaturalMessageText(parsed.body, maxLines: 2),
                          ],
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (createdAt != null)
                              Text(
                                DateUtils.isSameDay(
                                      createdAt.toLocal(),
                                      DateTime.now(),
                                    )
                                    ? TimeOfDay.fromDateTime(
                                        createdAt.toLocal(),
                                      ).format(context)
                                    : MaterialLocalizations.of(
                                        context,
                                      ).formatShortDate(createdAt.toLocal()),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            if (unread) ...[
                              const SizedBox(height: 8),
                              Semantics(
                                label: communityText(
                                  context,
                                  'Unread messages',
                                  'الرسائل غير المقروءة',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () async {
                          await context.push(
                            '/community/chat/$otherId?name=${Uri.encodeQueryComponent(name)}',
                          );
                          if (context.mounted) {
                            await onRetry();
                            if (context.mounted) {
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
