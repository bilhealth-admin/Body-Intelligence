import 'dart:convert';

/// One saved occurrence. Exercise ids and names are not unique log ids.
final class DailyStructuredExerciseEntry {
  const DailyStructuredExerciseEntry({
    required this.sourceLineIndex,
    required this.encodedLine,
    required this.displayName,
    this.recordedAt,
  });

  final int sourceLineIndex;
  final String encodedLine;
  final String displayName;
  final DateTime? recordedAt;
}

final class DailyExerciseNotesView {
  const DailyExerciseNotesView({
    required this.displayNames,
    required this.preservedStructuredLines,
    required this.manualText,
    this.entries = const <DailyStructuredExerciseEntry>[],
  });

  final List<String> displayNames;
  final List<String> preservedStructuredLines;
  final String manualText;
  final List<DailyStructuredExerciseEntry> entries;

  String? compose({required String manualText}) {
    final manual = manualText.trim();
    final lines = <String>[
      ...preservedStructuredLines,
      if (manual.isNotEmpty) manual,
    ];
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }
}

abstract final class DailyExerciseNotesCodec {
  // Keep each line's own terminator so deleting one occurrence leaves every
  // other byte (including malformed internal lines and manual notes) intact.
  static final _sourceLine = RegExp(r'[^\r\n]*(?:\r\n|\r|\n|$)');
  static final _terminator = RegExp(r'(?:\r\n|\r|\n)$');

  static List<RegExpMatch> _sourceLines(String raw) => _sourceLine
      .allMatches(raw)
      .where((match) => match.end > match.start)
      .toList(growable: false);

  static String? removeEntry(String raw, DailyStructuredExerciseEntry entry) {
    final lines = _sourceLines(raw);
    if (entry.sourceLineIndex < 0 || entry.sourceLineIndex >= lines.length) {
      throw StateError('exercise_entry_changed');
    }
    final line = lines[entry.sourceLineIndex];
    final payload = raw
        .substring(line.start, line.end)
        .replaceFirst(_terminator, '')
        .trim();
    final decoded = _decodeMap(payload);
    if (payload != entry.encodedLine ||
        decoded == null ||
        _displayName(decoded) != entry.displayName) {
      throw StateError('exercise_entry_changed');
    }
    final remaining = raw.replaceRange(line.start, line.end, '');
    return remaining.isEmpty ? null : remaining;
  }

  static DailyExerciseNotesView decode(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return const DailyExerciseNotesView(
        displayNames: <String>[],
        preservedStructuredLines: <String>[],
        manualText: '',
      );
    }

    final displayNames = <String>[];
    final structured = <String>[];
    final manual = <String>[];
    final entries = <DailyStructuredExerciseEntry>[];
    final source = raw!;
    final sourceLines = _sourceLines(source);

    for (final (index, sourceLine) in sourceLines.indexed) {
      final line = source
          .substring(sourceLine.start, sourceLine.end)
          .replaceFirst(_terminator, '')
          .trim();
      if (line.isEmpty) continue;

      final decoded = _decodeMap(line);
      if (decoded != null) {
        structured.add(line);
        final name = _displayName(decoded);
        if (name != null) {
          if (!displayNames.contains(name)) displayNames.add(name);
          final recordedAt = decoded['recordedAt'];
          entries.add(
            DailyStructuredExerciseEntry(
              sourceLineIndex: index,
              encodedLine: line,
              displayName: name,
              recordedAt: recordedAt is String
                  ? DateTime.tryParse(recordedAt)
                  : null,
            ),
          );
        }
        continue;
      }

      // JSON-shaped payloads are internal data even when malformed. Preserve
      // them for a later recovery/migration, but never render them as user copy.
      if (line.startsWith('{') || line.startsWith('[')) {
        structured.add(line);
        continue;
      }

      manual.add(line);
    }

    return DailyExerciseNotesView(
      displayNames: List<String>.unmodifiable(displayNames),
      preservedStructuredLines: List<String>.unmodifiable(structured),
      manualText: manual.join('\n'),
      entries: List<DailyStructuredExerciseEntry>.unmodifiable(entries),
    );
  }

  static Map<String, Object?>? _decodeMap(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return null;
      return Map<String, Object?>.from(decoded);
    } on Object {
      return null;
    }
  }

  static String? _displayName(Map<String, Object?> value) {
    for (final key in const ['title', 'name']) {
      final raw = value[key];
      if (raw is! String) continue;
      final text = raw.trim();
      if (text.isNotEmpty && text.length <= 200) return text;
    }
    return null;
  }
}
