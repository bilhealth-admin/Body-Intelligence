/// Stable codec for the structured Body context stored in `daily_logs.notes`.
///
/// Free-text notes remain private. Only the authored option tags returned by
/// [engineTypes] are allowed to cross into analytics or intelligence inputs.
abstract final class DailyBodyContextCodec {
  static const optionKeys = <String>[
    'poorSleep',
    'greatSleep',
    'travel',
    'fasting',
    'highSodiumMeal',
    'hardWorkout',
    'psychologicalStress',
    'illnessSymptoms',
    'medication',
    'lessWater',
    'moreWater',
    'constipation',
    'nothingNotable',
    'other',
  ];

  static const _engineTypeByOption = <String, String>{
    'poorSleep': 'poorSleep',
    'greatSleep': 'greatSleep',
    'travel': 'travel',
    'fasting': 'fasting',
    'highSodiumMeal': 'highSodiumMeal',
    'hardWorkout': 'hardWorkout',
    'psychologicalStress': 'stress',
    'illnessSymptoms': 'illness',
    'medication': 'medicationChange',
    'lessWater': 'lowHydration',
    'moreWater': 'highHydration',
    'constipation': 'constipation',
    'nothingNotable': 'nothingNotable',
    'other': 'other',
  };

  static DailyBodyContextSelection decode(String? encoded) {
    final value = encoded?.trim() ?? '';
    if (value.isEmpty) return const DailyBodyContextSelection();
    final tags = RegExp(r'\[([A-Za-z]+)\]').allMatches(value).toList();
    if (tags.isEmpty) {
      return DailyBodyContextSelection(note: value);
    }
    final selected = <String>{
      for (final match in tags)
        if (optionKeys.contains(match.group(1))) match.group(1)!,
    };
    if (selected.length > 1) selected.remove('nothingNotable');
    return DailyBodyContextSelection(
      selected: selected,
      note: _tagValue(value, 'note'),
      other: _tagValue(value, 'other'),
    );
  }

  static String encode({
    required Iterable<String> selected,
    String note = '',
    String other = '',
  }) {
    final safe = selected.where(optionKeys.contains).toSet();
    if (safe.length > 1) safe.remove('nothingNotable');
    final result = <String>[];
    if (note.trim().isNotEmpty) result.add('[note] ${note.trim()}');
    result.addAll(
      optionKeys
          .where(safe.contains)
          .where((option) => option != 'other')
          .map((option) => '[$option]'),
    );
    if (safe.contains('other')) {
      final detail = other.trim();
      result.add(detail.isEmpty ? '[other]' : '[other] $detail');
    }
    return result.join(' ');
  }

  static Set<String> engineTypes(String? encoded) => {
    for (final option in decode(encoded).selected)
      ?_engineTypeByOption[option],
  };

  static String _tagValue(String encoded, String tag) =>
      RegExp(
        '\\[$tag\\]\\s*(.*?)(?=\\s*\\[[A-Za-z]+\\]|\$)',
      ).firstMatch(encoded)?.group(1)?.trim() ??
      '';
}

final class DailyBodyContextSelection {
  const DailyBodyContextSelection({
    this.selected = const <String>{},
    this.note = '',
    this.other = '',
  });

  final Set<String> selected;
  final String note;
  final String other;
}
