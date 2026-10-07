import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_daily_brief.dart';
import 'package:flutter_test/flutter_test.dart';

const _keys = <String>{'caloriesKcal', 'proteinG', 'carbsG', 'fatG'};
const _targets = <String, Object?>{
  'caloriesKcal': 2000,
  'proteinG': 150,
  'carbsG': 200,
  'fatG': 70,
};
const _consumed = <String, double>{
  'caloriesKcal': 900,
  'proteinG': 45,
  'carbsG': 90,
  'fatG': 30,
};

CoachNutritionDay _day({
  String day = '2026-10-07',
  Map<String, double> values = _consumed,
  Set<String> known = _keys,
}) => CoachNutritionDay(
  day: day,
  meals: const [],
  calories: values['caloriesKcal']!,
  protein: values['proteinG']!,
  carbs: values['carbsG']!,
  fat: values['fatG']!,
  sodium: 0,
  knownTotals: known,
);

CoachContextSnapshot _snapshot({
  List<CoachNutritionDay>? days,
  Object? targets = _targets,
}) => CoachContextSnapshot(
  generatedAt: DateTime(2026, 10, 7, 12),
  profile: const {},
  weights: const [],
  nutritionDays: days ?? [_day()],
  waterHistory: const [],
  computedHealth: {'dailyTargets': targets},
);

void main() {
  final today = DateTime(2026, 10, 7, 12);

  test('missing day cannot be treated as known zero consumption', () {
    expect(_snapshot(days: []).nutritionRemainingFor(today), isNull);
  });

  test('another local day cannot supply the requested day totals', () {
    expect(
      _snapshot(days: [_day(day: '2026-10-06')]).nutritionRemainingFor(today),
      isNull,
    );
  });

  test('a present day with no known totals is still unavailable', () {
    expect(
      _snapshot(days: [_day(known: {})]).nutritionRemainingFor(today),
      isNull,
    );
  });

  for (final key in _keys) {
    test('missing $key target is not a zero target', () {
      final targets = {..._targets}..remove(key);
      expect(_snapshot(targets: targets).nutritionRemainingFor(today), isNull);
    });

    test('missing $key consumption evidence is unavailable', () {
      final known = {..._keys}..remove(key);
      expect(
        _snapshot(days: [_day(known: known)]).nutritionRemainingFor(today),
        isNull,
      );
    });

    for (final (label, invalid) in <(String, Object?)>[
      ('null', null),
      ('numeric string', '150'),
      ('boolean', true),
      ('list', <Object?>[]),
      ('map', <String, Object?>{}),
      ('NaN', double.nan),
      ('positive infinity', double.infinity),
      ('negative infinity', double.negativeInfinity),
      ('negative', -1),
    ]) {
      test('$key target $label cannot produce a remaining receipt', () {
        final targets = {..._targets, key: invalid};
        expect(
          _snapshot(targets: targets).nutritionRemainingFor(today),
          isNull,
        );
      });
    }

    for (final (label, invalid) in <(String, double)>[
      ('NaN', double.nan),
      ('positive infinity', double.infinity),
      ('negative infinity', double.negativeInfinity),
      ('negative', -1),
    ]) {
      test('$key consumed $label is invalid even when marked known', () {
        expect(
          _snapshot(
            days: [
              _day(values: {..._consumed, key: invalid}),
            ],
          ).nutritionRemainingFor(today),
          isNull,
        );
      });
    }
  }

  for (final targets in <Object?>[null, [], 'not targets', 42]) {
    test('invalid target container $targets is unavailable', () {
      expect(_snapshot(targets: targets).nutritionRemainingFor(today), isNull);
    });
  }

  test('documented zero targets and consumption stay known zero', () {
    final remaining = _snapshot(
      targets: {for (final key in _keys) key: 0},
      days: [
        _day(values: {for (final key in _keys) key: 0}),
      ],
    ).nutritionRemainingFor(today);
    expect(remaining, {for (final key in _keys) key: 0});
  });

  test(
    'valid same-day values subtract and excessive intake clamps to zero',
    () {
      final remaining = _snapshot(
        days: [
          _day(values: {..._consumed, 'proteinG': 160}),
        ],
      ).nutritionRemainingFor(today);
      expect(remaining, {
        'caloriesKcal': 1100,
        'proteinG': 0,
        'carbsG': 110,
        'fatG': 40,
      });
      expect(remaining!.values.every((value) => value.isFinite), isTrue);
    },
  );

  test('local civil date is stable from first to last minute of the day', () {
    final snapshot = _snapshot();
    final first = snapshot.nutritionRemainingFor(DateTime(2026, 10, 7, 0, 1));
    final last = snapshot.nutritionRemainingFor(DateTime(2026, 10, 7, 23, 59));
    expect(first, {
      'caloriesKcal': 1100,
      'proteinG': 105,
      'carbsG': 110,
      'fatG': 40,
    });
    expect(last, first);
    expect(snapshot.nutritionRemainingFor(DateTime(2026, 10, 8)), isNull);
  });

  test(
    'unavailable sodium does not erase known calorie and macro evidence',
    () {
      final day = _day();
      expect(day.knownTotals, isNot(contains('sodiumMg')));
      expect(_snapshot(days: [day]).nutritionRemainingFor(today), {
        'caloriesKcal': 1100,
        'proteinG': 105,
        'carbsG': 110,
        'fatG': 40,
      });
    },
  );

  test(
    'reading remaining nutrition does not change target or day evidence',
    () {
      final targets = {..._targets};
      final known = {..._keys};
      final day = _day(known: known);
      _snapshot(days: [day], targets: targets).nutritionRemainingFor(today);
      expect(targets, _targets);
      expect(known, _keys);
      expect(day.calories, 900);
      expect(day.protein, 45);
    },
  );

  for (final locale in ['en', 'ar']) {
    test('daily brief $locale never invents remaining amounts for no day', () {
      final brief = const CoachDailyBriefEngine().build(
        context: _snapshot(days: []),
        now: today,
        locale: locale,
      );
      expect(brief.kind, isNot(CoachDailyBriefKind.nutrition));
      expect(brief.message, isNot(contains('2000')));
      expect(brief.message, isNot(contains('150')));
      expect(brief.actionLabel, isNotEmpty);
    });
  }
}
