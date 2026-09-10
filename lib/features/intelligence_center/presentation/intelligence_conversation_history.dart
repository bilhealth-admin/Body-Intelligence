part of 'intelligence_center_page.dart';

const _conversationHistoryKey = 'intelligenceConversationHistoryV1';
const _activeConversationIdKey = 'intelligenceConversationActiveIdV1';
const _conversationHistoryStorageVersion = 2;

@immutable
class CoachConversationHistoryArchive {
  const CoachConversationHistoryArchive({
    required this.conversations,
    required this.activeConversationId,
    required this.needsMigration,
  });

  final List<Map<String, Object?>> conversations;
  final String? activeConversationId;
  final bool needsMigration;
}

String? _nonEmptyConversationId(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

List<Map<String, Object?>> _validConversationEntries(Object? rawEntries) {
  if (rawEntries is! List) return <Map<String, Object?>>[];
  final result = <Map<String, Object?>>[];
  for (final rawEntry in rawEntries.whereType<Map>()) {
    try {
      final entry = Map<String, Object?>.from(rawEntry);
      final id = _nonEmptyConversationId(entry['id']);
      final messages = entry['messages'];
      if (id == null || messages is! List) continue;
      result.add(<String, Object?>{
        ...entry,
        'id': id,
        'messages': List<Object?>.from(messages),
      });
    } on Object {
      // A malformed row cannot invalidate the rest of the local archive.
    }
  }
  return result;
}

/// Reads both the original bare-list format and the versioned local archive.
///
/// The legacy key is intentionally retained. Existing installs can migrate in
/// place without dropping any conversation that survived the old 20-item cap.
@visibleForTesting
CoachConversationHistoryArchive decodeCoachConversationHistory(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const CoachConversationHistoryArchive(
      conversations: <Map<String, Object?>>[],
      activeConversationId: null,
      needsMigration: false,
    );
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return CoachConversationHistoryArchive(
        conversations: _validConversationEntries(decoded),
        activeConversationId: null,
        needsMigration: true,
      );
    }
    if (decoded is Map) {
      final archive = Map<String, Object?>.from(decoded);
      return CoachConversationHistoryArchive(
        conversations: _validConversationEntries(archive['conversations']),
        activeConversationId: _nonEmptyConversationId(
          archive['activeConversationId'],
        ),
        needsMigration:
            archive['version'] != _conversationHistoryStorageVersion,
      );
    }
  } on Object {
    // A damaged index must not prevent the current transcript from opening.
  }
  return const CoachConversationHistoryArchive(
    conversations: <Map<String, Object?>>[],
    activeConversationId: null,
    needsMigration: false,
  );
}

@visibleForTesting
String encodeCoachConversationHistory({
  required List<Map<String, Object?>> conversations,
  required String? activeConversationId,
}) => jsonEncode(<String, Object?>{
  'version': _conversationHistoryStorageVersion,
  'activeConversationId': _nonEmptyConversationId(activeConversationId),
  'conversations': conversations,
});

/// Delete only the selected conversation. Unlike the tolerant display decoder,
/// this mutation preserves unrecognized rows and metadata and refuses a broken
/// index instead of silently replacing other user-owned chats with an empty list.
@visibleForTesting
String deleteCoachConversationFromArchive(String? raw, String? id) {
  final Object? decoded = raw == null || raw.trim().isEmpty
      ? <Object?>[]
      : jsonDecode(raw);
  final Map<String, Object?> archive;
  final List<Object?> entries;
  if (decoded is List) {
    archive = <String, Object?>{'version': _conversationHistoryStorageVersion};
    entries = List<Object?>.from(decoded);
  } else if (decoded is Map && decoded['conversations'] is List) {
    archive = Map<String, Object?>.from(decoded);
    entries = List<Object?>.from(decoded['conversations'] as List);
  } else {
    throw const FormatException('unreadable_conversation_archive');
  }
  if (id != null) {
    entries.removeWhere(
      (entry) => entry is Map && _nonEmptyConversationId(entry['id']) == id,
    );
  }
  return jsonEncode(<String, Object?>{
    ...archive,
    'activeConversationId':
        _nonEmptyConversationId(archive['activeConversationId']) == id
        ? null
        : archive['activeConversationId'],
    'conversations': entries,
  });
}

bool _sameConversationMessages(Object? left, Object? right) {
  if (left is! List || right is! List) return false;
  try {
    return jsonEncode(left) == jsonEncode(right);
  } on Object {
    return false;
  }
}

@visibleForTesting
String? migratedCoachConversationIdForMessages(List<Object?> messages) {
  if (messages.isEmpty) return null;
  // A bounded rolling hash gives the pre-history transcript the same identity
  // on native and web runtimes. It is persisted during migration, so this is
  // not used to merge unrelated conversations after that one-time upgrade.
  late final String encoded;
  try {
    encoded = jsonEncode(messages);
  } on Object {
    return null;
  }
  var hash = 0;
  for (final codeUnit in encoded.codeUnits) {
    hash = ((hash * 31) + codeUnit) & 0x1fffffff;
  }
  return 'conversation-legacy-${hash.toRadixString(16).padLeft(8, '0')}';
}

/// Resolves the durable selection without silently switching to the first or
/// newest conversation. Matching the current transcript is only a fallback
/// for legacy installs that predate the active-conversation preference.
@visibleForTesting
String? resolveCoachActiveConversationId({
  required String? storedActiveConversationId,
  required CoachConversationHistoryArchive archive,
  required List<Object?> currentMessages,
}) {
  final stored = _nonEmptyConversationId(storedActiveConversationId);
  if (stored != null) return stored;
  final archived = _nonEmptyConversationId(archive.activeConversationId);
  if (archived != null) return archived;
  if (currentMessages.isEmpty) return null;
  for (final entry in archive.conversations) {
    if (_sameConversationMessages(entry['messages'], currentMessages)) {
      return _nonEmptyConversationId(entry['id']);
    }
  }
  return migratedCoachConversationIdForMessages(currentMessages);
}

@visibleForTesting
List<Map<String, Object?>> upsertCoachConversationHistory({
  required List<Map<String, Object?>> history,
  required String id,
  required String title,
  required String createdAt,
  required List<Object?> messages,
}) {
  final existing = history.cast<Map<String, Object?>?>().firstWhere(
    (entry) => entry?['id'] == id,
    orElse: () => null,
  );
  final next = history
      .where((entry) => entry['id'] != id)
      .map(Map<String, Object?>.from)
      .toList();
  next.insert(0, <String, Object?>{
    ...?existing,
    'id': id,
    'title': title,
    'createdAt': existing?['createdAt'] ?? createdAt,
    'messages': List<Object?>.from(messages),
  });
  return next;
}

extension _IntelligenceConversationHistory on _IntelligenceCenterPageState {
  Future<void> _openConversationHistory({bool deleteMode = false}) async {
    if (!mounted ||
        !conversationReady ||
        conversationHistoryOpening ||
        foodImageFlowOpening) {
      return;
    }
    conversationHistoryOpening = true;
    try {
      await _showConversationHistory(deleteMode: deleteMode);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Try again', 'أعد المحاولة'))),
        );
      }
    } finally {
      conversationHistoryOpening = false;
    }
  }

  Future<void> _showConversationHistory({required bool deleteMode}) async {
    final repository = conversationPreferences;
    final archive = decodeCoachConversationHistory(
      await repository.get(_conversationHistoryKey),
    );
    if (!mounted) return;
    final history = archive.conversations.toList(growable: true);
    activeConversationId ??= archive.activeConversationId;
    // Snapshot the current chat before presenting the picker. This keeps its
    // title and turns current, and prevents selecting a stale copy of the
    // conversation that is already open.
    if (deleteMode) {
      // Selection/cancellation must not mutate the archive. Include the live
      // transcript even when it has not yet been archived by New conversation.
      final currentId = activeConversationId;
      final current = messages
          .where((item) => !item.id.startsWith('welcome'))
          .toList();
      if (currentId != null && current.isNotEmpty) {
        final userTurns = current.where(
          (item) => item.role == IntelligenceMessageRole.user,
        );
        final title = userTurns.isEmpty
            ? tr('Conversation', 'محادثة')
            : userTurns.first.text;
        final updated = upsertCoachConversationHistory(
          history: history,
          id: currentId,
          title: title,
          createdAt: current.first.createdAt.toIso8601String(),
          messages: current.map((item) => item.toJson()).toList(),
        );
        history
          ..clear()
          ..addAll(updated);
      }
    } else {
      await _archiveCurrentConversation(history);
    }
    if (!mounted) return;
    final selection = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
          children: [
            Text(
              deleteMode
                  ? tr('Clear conversation', 'مسح المحادثة')
                  : tr('Conversations', 'المحادثات'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              deleteMode
                  ? tr(
                      'Choose the conversation to delete',
                      'اختر المحادثة التي تريد حذفها',
                    )
                  : tr(
                      'Conversation history is stored locally on this device.',
                      'يُحفظ سجل المحادثات محليًا على هذا الجهاز.',
                    ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in history)
              ListTile(
                key: Key('ai-coach-conversation-${entry['id']}'),
                leading: const BilSemanticIconBadge(
                  kind: BilSemanticIconKind.messages,
                ),
                title: Text(
                  '${entry['title'] ?? tr('Conversation', 'محادثة')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${entry['createdAt'] ?? ''}'),
                selected: entry['id'] == activeConversationId,
                trailing: deleteMode
                    ? Icon(
                        Icons.delete_outline,
                        semanticLabel: tr('Delete', 'حذف'),
                      )
                    : entry['id'] == activeConversationId
                    ? Icon(
                        Icons.check_circle_rounded,
                        semanticLabel: tr(
                          'Current conversation',
                          'المحادثة الحالية',
                        ),
                      )
                    : null,
                onTap: () => Navigator.pop(sheetContext, '${entry['id']}'),
              ),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  tr(
                    'No previous conversations yet.',
                    'لا توجد محادثات سابقة بعد.',
                  ),
                ),
              ),
            if (!deleteMode) const Divider(height: 20),
            if (!deleteMode)
              ListTile(
                leading: const BilSemanticIconBadge(
                  kind: BilSemanticIconKind.messages,
                  iconOverride: Icons.add_comment_outlined,
                  appleIconOverride: Icons.add_comment_outlined,
                ),
                title: Text(tr('New conversation', 'محادثة جديدة')),
                subtitle: Text(
                  tr(
                    'Keep this chat in history and start an empty one.',
                    'احفظ هذه المحادثة في السجل وابدأ محادثة فارغة.',
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, '__new__'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;
    if (deleteMode) {
      final selected = history.firstWhere((entry) => entry['id'] == selection);
      await _deleteConversation(selection, title: '${selected['title'] ?? ''}');
      return;
    }
    // A reply can finish while the history picker is open. Stop that request,
    // archive the latest visible turns, and invalidate all older queued saves
    // before replacing the active transcript.
    _cancelCurrentCoachRequest();
    await _archiveCurrentConversation(history);
    if (!mounted) return;
    await _invalidatePendingConversationSaves();
    if (!mounted) return;
    if (selection == '__new__') {
      activeConversationId = null;
      await repository.mutate(
        set: <String, String>{
          _conversationHistoryKey: encodeCoachConversationHistory(
            conversations: history,
            activeConversationId: null,
          ),
        },
        remove: const <String>{
          'intelligenceConversationV1',
          'intelligenceConversationContextV1',
          _activeConversationIdKey,
        },
      );
      await _loadConversation();
      return;
    }
    Map<String, Object?>? selected;
    for (final entry in history) {
      if (entry['id'] == selection) {
        selected = entry;
        break;
      }
    }
    final selectedMessages = selected?['messages'];
    if (selectedMessages is! List) return;
    final revision = await _coachContextRevision();
    if (!mounted) return;
    activeConversationId = selection;
    await repository.setMany({
      'intelligenceConversationV1': jsonEncode(selectedMessages),
      'intelligenceConversationContextV1': revision.fingerprint,
      _activeConversationIdKey: selection,
      _conversationHistoryKey: encodeCoachConversationHistory(
        conversations: history,
        activeConversationId: selection,
      ),
    });
    await _loadConversation();
  }

  Future<void> _archiveCurrentConversation(
    List<Map<String, Object?>> history,
  ) async {
    if (!mounted) return;
    final repository = conversationPreferences;
    final fallbackTitle = tr('Conversation', 'محادثة');
    final idBeforeSave = activeConversationId;
    await _saveConversation();
    if (!mounted) return;
    final raw = await repository.get('intelligenceConversationV1');
    if (!mounted) return;
    if (raw == null || raw.trim().isEmpty) return;
    List<Object?> messages;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return;
      messages = decoded;
    } on Object {
      return;
    }
    var conversationId = activeConversationId;
    if (idBeforeSave == null) {
      final encodedMessages = jsonEncode(messages);
      for (final entry in history) {
        if (jsonEncode(entry['messages']) == encodedMessages &&
            entry['id'] is String) {
          conversationId = entry['id']! as String;
          break;
        }
      }
    }
    if (conversationId == null || conversationId.trim().isEmpty) return;
    activeConversationId = conversationId;
    final firstUser = messages.whereType<Map>().firstWhere(
      (entry) => entry['role'] == 'user',
      orElse: () => const <String, Object?>{},
    );
    final rawTitle = '${firstUser['text'] ?? fallbackTitle}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final title = rawTitle.length > 52
        ? '${rawTitle.substring(0, 52).trim()}…'
        : rawTitle;
    final updated = upsertCoachConversationHistory(
      history: history,
      id: conversationId,
      title: title.isEmpty ? fallbackTitle : title,
      createdAt: DateTime.now().toIso8601String(),
      messages: messages,
    );
    history
      ..clear()
      ..addAll(updated);
    await repository.setMany({
      _conversationHistoryKey: encodeCoachConversationHistory(
        conversations: history,
        activeConversationId: conversationId,
      ),
      _activeConversationIdKey: conversationId,
    });
  }
}
