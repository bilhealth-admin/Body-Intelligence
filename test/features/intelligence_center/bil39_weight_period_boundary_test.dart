import 'dart:convert';

import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_weight_history_readout.dart';
import 'package:flutter_test/flutter_test.dart';

CoachContextSnapshot _snapshot(List<CoachWeightPoint> points) =>
    CoachContextSnapshot(
      generatedAt: DateTime(2026, 10, 26, 12),
      profile: const {'targetWeightKg': 60},
      weights: points,
      weightReadStatus: CoachWeightReadStatus.verified,
      nutritionDays: const [],
      waterHistory: const [],
      computedHealth: const {},
    );

void main() {
  for (final scenario in [
    (days: 7, language: 'en', question: 'My weight over the last 7 days'),
    (days: 14, language: 'ar', question: 'حلل وزني خلال أسبوعين'),
    (days: 30, language: 'en', question: 'My weight over the last 30 days'),
    (days: 30, language: 'ar', question: 'حلل وزني خلال آخر شهر'),
    (days: 365, language: 'en', question: 'My weight over the last year'),
  ]) {
    test(
      '${scenario.days}-day weight window includes today once in ${scenario.language}',
      () {
        final now = DateTime(2026, 10, 26, 12);
        final today = DateTime(now.year, now.month, now.day);
        final points = [
          CoachWeightPoint(
            at: today.subtract(Duration(days: scenario.days)),
            kg: 95,
          ),
          CoachWeightPoint(
            at: today.subtract(Duration(days: scenario.days - 1)),
            kg: 90,
          ),
          CoachWeightPoint(at: today, kg: 88),
        ];
        final snapshot = _snapshot(points);
        final before = jsonEncode(snapshot.toJson());
        final result = CoachWeightHistoryReadout.build(
          snapshot: snapshot,
          question: scenario.question,
          languageTag: scenario.language,
          now: now,
        );
        expect(result.recordCount, 3);
        expect(result.comparableCount, 2);
        expect(result.changeKg, closeTo(-2, 0.0001));
        expect(jsonEncode(snapshot.toJson()), before);
      },
    );
  }

  for (final language in ['ar', 'en']) {
    test('28 stored weights retain three unknown days in $language', () {
      final now = DateTime(2026, 10, 26, 12);
      final today = DateTime(now.year, now.month, now.day);
      const missing = {4, 12, 18};
      // 27 recorded dates in the requested 30-day window, plus one older
      // measurement: 28 actual rows, without inventing a second daily record.
      final points = [
        for (var offset = 0; offset < 30; offset++)
          if (!missing.contains(offset))
            CoachWeightPoint(
              at: today.subtract(Duration(days: offset)),
              kg: 84 + offset / 10,
            ),
        CoachWeightPoint(at: today.subtract(const Duration(days: 45)), kg: 92),
      ];
      final snapshot = _snapshot(points);
      final before = jsonEncode(snapshot.toJson());
      final result = CoachWeightHistoryReadout.build(
        snapshot: snapshot,
        question: language == 'ar' ? 'حلل وزني آخر شهر' : 'Last 30 days weight',
        languageTag: language,
        now: now,
      );
      expect(points, hasLength(28));
      expect(result.recordCount, 28);
      expect(result.comparableCount, 27);
      expect(result.changeKg, closeTo(-2.9, 0.0001));
      expect(
        result.message,
        contains(language == 'ar' ? 'الأيام غير المسجلة' : 'missing dates'),
      );
      expect(jsonEncode(snapshot.toJson()), before);
      for (final offset in missing) {
        final day = today.subtract(Duration(days: offset));
        expect(points.any((point) => point.at == day), isFalse);
      }
    });
  }
}
