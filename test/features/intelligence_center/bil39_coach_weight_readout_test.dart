import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_weight_history_readout.dart';
import 'package:flutter_test/flutter_test.dart';

CoachContextSnapshot _fixture({
  CoachWeightReadStatus status = CoachWeightReadStatus.verified,
  List<CoachWeightPoint>? weights,
}) => CoachContextSnapshot(
  generatedAt: DateTime.utc(2026, 10, 25),
  profile: const <String, Object?>{
    // Goal is deliberately distinct from every actual weigh-in.
    'targetWeightKg': 60,
  },
  weights: weights ??
      [
        CoachWeightPoint(at: DateTime.utc(2026, 8, 20), kg: 93),
        CoachWeightPoint(at: DateTime.utc(2026, 10, 1), kg: 90),
        CoachWeightPoint(at: DateTime.utc(2026, 10, 23), kg: 88),
      ],
  weightReadStatus: status,
  nutritionDays: const <CoachNutritionDay>[],
  waterHistory: const <Map<String, Object?>>[],
  computedHealth: const <String, Object?>{},
);

void main() {
  final now = DateTime.utc(2026, 10, 25, 12);

  test('a verified 30-day question reports only dated recorded entries', () {
    final result = CoachWeightHistoryReadout.build(
      snapshot: _fixture(),
      question: 'حلل سجل أوزاني آخر شهر',
      languageTag: 'ar',
      now: now,
    );
    expect(result.recordCount, 3);
    expect(result.comparableCount, 2);
    expect(result.changeKg, closeTo(-2, 0.001));
    expect(result.message, contains('2026-10-01'));
    expect(result.message, contains('2026-10-23'));
    expect(result.message, contains('-2.0'));
    expect(result.message, isNot(contains('60')));
    expect(result.message, contains('لا تثبت تغيّر الدهون'));
  });

  test('full history is sorted and uses actual first/last, not goal', () {
    final result = CoachWeightHistoryReadout.build(
      snapshot: _fixture(
        weights: [
          CoachWeightPoint(at: DateTime.utc(2026, 10, 23), kg: 88),
          CoachWeightPoint(at: DateTime.utc(2026, 8, 20), kg: 93),
          CoachWeightPoint(at: DateTime.utc(2026, 10, 1), kg: 90),
        ],
      ),
      question: 'Review my weight history',
      languageTag: 'en',
      now: now,
    );
    expect(result.comparableCount, 3);
    expect(result.changeKg, closeTo(-5, 0.001));
    expect(result.message, contains('-5.0'));
    expect(result.message, isNot(contains('60.0')));
    expect(result.message, contains('not proof of body-fat change'));
  });

  test('a lone weigh-in cannot imply a trend', () {
    final result = CoachWeightHistoryReadout.build(
      snapshot: _fixture(
        weights: [
          CoachWeightPoint(at: DateTime.utc(2026, 10, 23), kg: 88),
        ],
      ),
      question: 'Last month weight trend',
      languageTag: 'en',
      now: now,
    );
    expect(result.comparableCount, 1);
    expect(result.changeKg, isNull);
    expect(result.message, contains('At least two'));
  });

  test('verified absence is separate from a failed repository read', () {
    final verifiedEmpty = CoachWeightHistoryReadout.build(
      snapshot: _fixture(weights: []),
      question: 'سجل أوزاني',
      languageTag: 'ar',
      now: now,
    );
    expect(verifiedEmpty.recordCount, 0);
    expect(verifiedEmpty.message, contains('نجحت قراءة سجل الوزن'));
    expect(
      () => CoachWeightHistoryReadout.build(
        snapshot: _fixture(status: CoachWeightReadStatus.unavailable),
        question: 'Weight history',
        languageTag: 'en',
        now: now,
      ),
      throwsStateError,
    );
    expect(
      () => CoachWeightHistoryReadout.build(
        snapshot: _fixture(status: CoachWeightReadStatus.withheld),
        question: 'Weight history',
        languageTag: 'en',
        now: now,
      ),
      throwsStateError,
    );
  });

  test('two weeks means 14 days in Arabic and English, never 7', () {
    for (final question in <String>['آخر أسبوعين', 'last two weeks']) {
      final result = CoachWeightHistoryReadout.build(
        snapshot: _fixture(
          weights: [
            CoachWeightPoint(at: DateTime.utc(2026, 10, 10), kg: 90),
            CoachWeightPoint(at: DateTime.utc(2026, 10, 17), kg: 89),
            CoachWeightPoint(at: DateTime.utc(2026, 10, 23), kg: 88),
          ],
        ),
        question: question,
        languageTag: question.startsWith('آخر') ? 'ar' : 'en',
        now: now,
      );
      expect(result.recordCount, 3, reason: question);
      expect(result.comparableCount, 2, reason: question);
      expect(result.changeKg, closeTo(-1, 0.001), reason: question);
    }
  });

  test('missing dates are not imputed to a recent period', () {
    final result = CoachWeightHistoryReadout.build(
      snapshot: _fixture(
        weights: [
          CoachWeightPoint(at: DateTime.utc(2026, 1, 20), kg: 93),
          CoachWeightPoint(at: DateTime.utc(2026, 2, 22), kg: 90),
        ],
      ),
      question: 'Show last 30 days',
      languageTag: 'en',
      now: now,
    );
    expect(result.recordCount, 2);
    expect(result.comparableCount, 0);
    expect(result.changeKg, isNull);
    expect(result.message, contains('no change can be calculated'));
  });
}
