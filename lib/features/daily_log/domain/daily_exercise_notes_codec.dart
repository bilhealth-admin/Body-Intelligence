import 'dart:convert';

final class DailyExerciseNotesView {
  const DailyExerciseNotesView({
    required this.displayNames,
    required this.preservedStructuredLines,
    required this.manualText,
  });

  final List<String> displayNames;
  final List<String> preservedStructuredLines;
  final String manualText;

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

    for (final sourceLine in const LineSplitter().convert(value)) {
      final line = sourceLine.trim();
      if (line.isEmpty) continue;

      final decoded = _decodeMap(line);
      if (decoded != null) {
        structured.add(line);
        final name = _displayName(decoded);
        if (name != null && !displayNames.contains(name)) {
          displayNames.add(name);
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
