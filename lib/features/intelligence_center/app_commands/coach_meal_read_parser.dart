// No model numbers, mutation, plan change, or cloud contract is involved.
import '../app_commands/coach_health_adapter.dart';

final class CoachMealReadColumnRequest {
  const CoachMealReadColumnRequest(this.day, this.mealType);
  final DateTime day;
  final String mealType;
}

final class CoachMealReadRequest {
  const CoachMealReadRequest(this.columns);
  final List<CoachMealReadColumnRequest> columns;
  bool get compare => columns.length > 1;
}

enum CoachMealReadIntentState { ignored, clarification, ready }

final class CoachMealReadIntent {
  const CoachMealReadIntent(this.state, [this.request]);
  final CoachMealReadIntentState state;
  final CoachMealReadRequest? request;
}

final class CoachMealReadParser {
  const CoachMealReadParser();
  static const _types = <String, String>{
    'breakfast': 'breakfast',
    'lunch': 'lunch',
    'dinner': 'dinner',
    'snack': 'snack',
    'الإفطار': 'breakfast',
    'الافطار': 'breakfast',
    'الفطور': 'breakfast',
    'الغداء': 'lunch',
    'العشاء': 'dinner',
    'الوجبة الخفيفة': 'snack',
    'السناك': 'snack',
  };
  static final _meal = _types.keys.map(RegExp.escape).join('|');

  CoachMealReadIntent parse(String input, {required DateTime referenceLocal}) {
    final normalized = _digits(input.trim()).replaceAll(RegExp(r'\s+'), ' ');
    final value = normalized.toLowerCase();
    final mealAppears = RegExp('(?:$_meal)', unicode: true).hasMatch(value);
    final readAppears = RegExp(
      r'^(?:compare|show|nutrition for|قارن|اعرض|أظهر)(?:\s|$)',
      unicode: true,
    ).hasMatch(value);
    if (!mealAppears || !readAppears) {
      return const CoachMealReadIntent(CoachMealReadIntentState.ignored);
    }
    if (value.length > 500) {
      return const CoachMealReadIntent(CoachMealReadIntentState.clarification);
    }
    // Date-qualified sides are parsed independently. A common trailing date
    // is explicit, and assigned to both sides rather than guessed from prose.
    final compare = RegExp(
      r'^(?:compare|قارن(?: بين)?) (.+?)(?: with | vs | and | مع | و)(.+)$',
      unicode: true,
    ).firstMatch(value);
    if (compare != null) {
      final first = _side(compare[1]!.trim(), referenceLocal);
      final second = _side(compare[2]!.trim(), referenceLocal);
      if (first == null || second == null) {
        return const CoachMealReadIntent(
          CoachMealReadIntentState.clarification,
        );
      }
      // If only the second side states a date, that date is the common suffix.
      final firstExplicit = _hasDate(compare[1]!);
      final secondExplicit = _hasDate(compare[2]!);
      final a = !firstExplicit && secondExplicit
          ? CoachMealReadColumnRequest(second.day, first.mealType)
          : first;
      if (a.day == second.day && a.mealType == second.mealType) {
        return const CoachMealReadIntent(
          CoachMealReadIntentState.clarification,
        );
      }
      return CoachMealReadIntent(
        CoachMealReadIntentState.ready,
        CoachMealReadRequest(List.unmodifiable([a, second])),
      );
    }
    final show = RegExp(
      r'^(?:show|nutrition for|اعرض|أظهر) (.+?)(?: nutrition| nutrients| تغذية)?$',
      unicode: true,
    ).firstMatch(value);
    final column = show == null ? null : _side(show[1]!.trim(), referenceLocal);
    if (column == null) {
      return const CoachMealReadIntent(CoachMealReadIntentState.clarification);
    }
    return CoachMealReadIntent(
      CoachMealReadIntentState.ready,
      CoachMealReadRequest(List.unmodifiable([column])),
    );
  }

  CoachMealReadColumnRequest? _side(String input, DateTime reference) {
    input = input.replaceAll(
      RegExp(r' (?:nutrition|nutrients|تغذية|المغذيات)(?= |$)'),
      '',
    );
    final match = RegExp(
      '^($_meal)(?: (today|yesterday|اليوم|أمس|امس|(?:on |بتاريخ )?[0-9]{4}-[0-9]{2}-[0-9]{2}))?\$',
      unicode: true,
    ).firstMatch(input);
    if (match == null) return null;
    final type = _types[match[1]];
    if (type == null) return null;
    final rawDay = match[2];
    final today = DateTime(reference.year, reference.month, reference.day);
    final DateTime day;
    if (rawDay == null || rawDay == 'today' || rawDay == 'اليوم') {
      day = today;
    } else if (const {'yesterday', 'أمس', 'امس'}.contains(rawDay)) {
      day = DateTime(today.year, today.month, today.day - 1);
    } else {
      try {
        day = parseHealthDay(
          rawDay.replaceFirst(RegExp(r'^(?:on |بتاريخ )'), ''),
        );
      } on Object {
        return null;
      }
    }
    return CoachMealReadColumnRequest(day, type);
  }

  bool _hasDate(String input) => RegExp(
    r'(?:today|yesterday|اليوم|أمس|امس|[0-9]{4}-[0-9]{2}-[0-9]{2})$',
    unicode: true,
  ).hasMatch(input.trim());

  String _digits(String text) {
    // Reuse/expose the existing health parser normalizer in final source if
    // feasible; this is only a draft of the same documented input mapping.
    const ar = '٠١٢٣٤٥٦٧٨٩', fa = '۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < 10; i++) {
      text = text.replaceAll(ar[i], '$i').replaceAll(fa[i], '$i');
    }
    return text;
  }
}
