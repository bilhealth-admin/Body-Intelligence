import 'dart:convert';
import 'package:flutter/widgets.dart';

const coachConversationTitleLimit = 60;
const coachConversationHistoryKey = 'intelligenceConversationHistoryV1';

String validatedCoachConversationTitle(String value) {
  final title = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty) throw const FormatException('empty_conversation_title');
  if (title.characters.length > coachConversationTitleLimit) {
    throw const FormatException('conversation_title_too_long');
  }
  return title;
}

String abbreviatedCoachConversationTitle(String value, [int limit = 52]) =>
    value.characters.length > limit
    ? '${value.characters.take(limit).toString().trim()}…'
    : value;

/// The strict mutation codec retains unknown rows, root metadata and receipts.
Map<String, Object?> coachConversationArchiveForMutation(String? raw) {
  final Object? decoded = raw == null || raw.trim().isEmpty
      ? <Object?>[]
      : jsonDecode(raw);
  if (decoded is List) {
    return {'version': 2, 'conversations': List<Object?>.from(decoded)};
  }
  if (decoded is Map && decoded['conversations'] is List) {
    return Map<String, Object?>.from(decoded);
  }
  throw const FormatException('unreadable_conversation_archive');
}

String renameCoachConversationInArchive(String? raw, String id, String value) {
  final title = validatedCoachConversationTitle(value);
  final archive = coachConversationArchiveForMutation(raw);
  var found = false;
  final entries = <Object?>[
    for (final entry in archive['conversations']! as List)
      if (entry is Map && entry['id'] == id)
        () {
          found = true;
          return <String, Object?>{
            ...Map<String, Object?>.from(entry),
            'title': title,
            'titleSource': 'manual',
          };
        }()
      else
        entry,
  ];
  if (!found) throw StateError('conversation_missing');
  return jsonEncode({...archive, 'version': 2, 'conversations': entries});
}

String upsertCoachConversationArchive({
  required String? raw,
  required String id,
  required String automaticTitle,
  required String createdAt,
  required List<Object?> messages,
  required String? activeId,
}) {
  final archive = coachConversationArchiveForMutation(raw);
  if ((archive['deletedConversationIds'] as List?)?.contains(id) == true) {
    throw StateError('conversation_deleted');
  }
  Map<String, Object?>? existing;
  final other = <Object?>[];
  for (final entry in archive['conversations']! as List) {
    if (entry is Map && entry['id'] == id) {
      existing = Map<String, Object?>.from(entry);
    } else {
      other.add(entry);
    }
  }
  final entry = <String, Object?>{
    ...?existing,
    'id': id,
    'title': existing?['titleSource'] == 'manual'
        ? existing!['title']
        : automaticTitle,
    'createdAt': existing?['createdAt'] ?? createdAt,
    'messages': _mergeMessages(existing?['messages'], messages),
  };
  return jsonEncode({
    ...archive,
    'version': 2,
    'activeConversationId': activeId,
    'conversations': [entry, ...other],
  });
}

List<Object?> _mergeMessages(Object? previous, List<Object?> incoming) {
  if (previous is! List) return incoming;
  final pending = List<Object?>.from(incoming);
  final merged = <Object?>[];
  for (final old in previous) {
    final index = pending.indexWhere(
      (next) =>
          old is Map &&
          next is Map &&
          old['id'] != null &&
          old['id'] == next['id'],
    );
    if (index < 0) {
      merged.add(old);
      continue;
    }
    final next = pending.removeAt(index) as Map;
    merged.add(<String, Object?>{
      ...Map<String, Object?>.from(old as Map),
      ...Map<String, Object?>.from(next),
    });
  }
  return [...merged, ...pending];
}
