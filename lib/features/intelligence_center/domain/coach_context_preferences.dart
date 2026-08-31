import 'dart:convert';

/// User-selected boundaries for the context BIL may assemble for AI Coach.
///
/// This is not cloud consent. Remote AI remains locked by the authoritative
/// server consent gate. These preferences only reduce the local snapshot that
/// can be offered after that separate consent succeeds.
enum CoachContextFocus { nutrition, training, habits, analytics }

final class CoachContextPreferences {
  const CoachContextPreferences({
    this.focuses = const <CoachContextFocus>{
      CoachContextFocus.nutrition,
      CoachContextFocus.training,
      CoachContextFocus.habits,
      CoachContextFocus.analytics,
    },
  });

  static const storageKey = 'aiCoach.contextPreferences.v1';

  final Set<CoachContextFocus> focuses;

  bool includes(CoachContextFocus focus) => focuses.contains(focus);

  String encode() => jsonEncode(<String, Object?>{
    'version': 1,
    'focuses': focuses.map((value) => value.name).toList()..sort(),
  });

  static CoachContextPreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const CoachContextPreferences();
    }
    try {
      final value = jsonDecode(raw);
      if (value is! Map || value['version'] != 1 || value['focuses'] is! List) {
        return const CoachContextPreferences();
      }
      final names = (value['focuses'] as List<Object?>)
          .map((item) => item?.toString())
          .whereType<String>()
          .toSet();
      final selected = CoachContextFocus.values
          .where((focus) => names.contains(focus.name))
          .toSet();
      // An explicitly saved empty list is meaningful: the user chose not to
      // include any local context category. Only a missing or malformed
      // preference falls back to the backwards-compatible defaults above.
      return CoachContextPreferences(focuses: Set.unmodifiable(selected));
    } on FormatException {
      return const CoachContextPreferences();
    } on TypeError {
      return const CoachContextPreferences();
    }
  }
}
