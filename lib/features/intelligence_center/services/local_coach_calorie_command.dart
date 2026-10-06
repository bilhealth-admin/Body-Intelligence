import '../domain/intelligence_action.dart';
import '../intelligence_locale_copy.dart';
import 'coach_date_resolver.dart';

/// A bounded calorie-only entry, never a daily-total replacement or food guess.
/// Unrecognized words, corrections, questions and compound quantities stay in
/// the normal dialogue path. The native command still requires fresh review.
final class LocalCoachCalorieCommand {
  const LocalCoachCalorieCommand({
    this.dateResolver = const CoachDateResolver(),
  });

  final CoachDateResolver dateResolver;

  static const _number = r'(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?';
  static final _entry = RegExp(
    '^(?:(?:please\\s+)?(?:log|record|add)\\s+|'
    '(?:سجل|اضف|دون)(?:\\s+لي)?\\s+)?'
    '($_number)\\s*'
    '(?:kcal|kilocalories?|calories?|سعرات?(?:\\s+حرارية)?|'
    'سعرة(?:\\s+حرارية)?|كالوري|كيلوكالوري)'
    '(?:\\s+(?:only|فقط))?'
    '(?:\\s+(?:without (?:meals|foods)|no (?:meals|foods)|'
    'بدون (?:وجبات|اكل|طعام)))?'
    '(?:\\s+(?:only|فقط|please))?\\s*[.!]*\$',
    unicode: true,
  );
  static final _today = _tokens('today|اليوم|النهارده|النهاردة');
  static final _yesterday = _tokens('yesterday|امس|مبارح');
  static final _mealNames = <String, RegExp>{
    'breakfast': _tokens('breakfast|الفطور|فطور|الفطار|فطار|للفطور|للفطار'),
    'lunch': _tokens('lunch|الغداء|غداء|الغدا|للغداء|للغدا'),
    'dinner': _tokens('dinner|العشاء|عشاء|العشا|عشا|للعشاء|للعشا'),
    'snack': _tokens('snack|سناك|وجبة خفيفة'),
  };

  IntelligenceAction? parse(
    String input, {
    required String locale,
    DateTime? referenceLocal,
  }) {
    if (input.contains('?') || input.contains('؟')) return null;
    final reference = (referenceLocal ?? DateTime.now()).toLocal();
    var value = _normalize(input);
    final explicit = dateResolver.hasExplicitDate(value);
    final date = dateResolver.resolve(value, referenceLocal: reference);
    if (explicit && date == null) return null;
    final today = _today.hasMatch(value);
    final yesterday = _yesterday.hasMatch(value);
    if (!explicit && today && yesterday) return null;

    value = dateResolver.withoutExplicitDates(value);
    final meals = <String>[];
    for (final entry in _mealNames.entries) {
      if (entry.value.hasMatch(value)) {
        meals.add(entry.key);
        value = value.replaceAll(entry.value, ' ');
      }
    }
    if (meals.length > 1) return null;
    value = value.replaceAll(_today, ' ').replaceAll(_yesterday, ' ');
    // Context connectors are allowed only when a real context was found.
    // Remaining unrecognized words cannot be silently discarded.
    if (explicit || today || yesterday || meals.isNotEmpty) {
      value = value.replaceAll(_tokens('on|for|في|بتاريخ|ليوم|يوم'), ' ');
    }
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = _entry.firstMatch(value);
    if (match == null) return null;
    final calories = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (calories == null ||
        !calories.isFinite ||
        calories <= 0 ||
        calories > 10000) {
      return null;
    }
    final day = date ?? DateTime(reference.year, reference.month, reference.day);
    final dayText =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final meal = meals.isNotEmpty ? meals.single : _suggestMeal(reference.hour);
    final amount = calories == calories.roundToDouble()
        ? calories.toInt().toString()
        : calories.toString();
    final quickAdd = intelligenceTextFor(locale, 'Quick Add', 'إضافة سريعة');
    final calorieLabel = intelligenceTextFor(locale, 'Calories', 'السعرات');
    final mealLabel = switch (meal) {
      'breakfast' => intelligenceTextFor(locale, 'Breakfast', 'الفطور'),
      'lunch' => intelligenceTextFor(locale, 'Lunch', 'الغداء'),
      'dinner' => intelligenceTextFor(locale, 'Dinner', 'العشاء'),
      _ => intelligenceTextFor(locale, 'Snack', 'وجبة خفيفة'),
    };
    return IntelligenceAction(
      id: 'calorie-only-$dayText-$meal-$amount',
      toolId: 'quick_add_macros',
      type: IntelligenceActionType.quickAddMacros,
      label: '$quickAdd · $calorieLabel: $amount kcal · $mealLabel · $dayText',
      requiresConfirmation: true,
      requiresFreshConfirmation: true,
      payload: Map<String, Object?>.unmodifiable({
        'mealType': meal,
        'date': dayText,
        'calories': calories,
      }),
    );
  }

  // A suggested review bucket, not a claim about when food was consumed.
  static String _suggestMeal(int hour) {
    if (hour >= 5 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 16) return 'lunch';
    if (hour >= 16 && hour < 22) return 'dinner';
    return 'snack';
  }

  static RegExp _tokens(String alternatives) => RegExp(
    '(?<![\\p{L}\\p{N}])(?:$alternatives)(?![\\p{L}\\p{N}])',
    unicode: true,
  );

  static String _normalize(String input) {
    var value = input.trim().toLowerCase();
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const eastern = '۰۱۲۳۴۵۶۷۸۹';
    for (var digit = 0; digit < 10; digit++) {
      value = value
          .replaceAll(arabic[digit], '$digit')
          .replaceAll(eastern[digit], '$digit');
    }
    return value
        .replaceAll(RegExp(r'[\u0640\u064b-\u065f\u0670\u06d6-\u06ed]'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('٫', '.')
        .replaceAll('٬', ',');
  }
}
