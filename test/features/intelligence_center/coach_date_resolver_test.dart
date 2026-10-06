import 'package:body_intelligence_log/features/intelligence_center/services/coach_date_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = CoachDateResolver();
  final reference = DateTime(2026, 8, 11, 23, 40); // Tuesday in user locale.

  test('relative dates resolve against explicit user-local reference', () {
    expect(
      resolver.resolve('أمس', referenceLocal: reference),
      DateTime(2026, 8, 10),
    );
    expect(
      resolver.resolve('قبل أسبوع', referenceLocal: reference),
      DateTime(2026, 8, 4),
    );
    expect(
      resolver.resolve('today', referenceLocal: reference),
      DateTime(2026, 8, 11),
    );
  });

  test('dialect Sunday resolves to the previous completed Sunday', () {
    for (final phrase in const ['الأحد اللي فات', 'يوم الحد', 'عالأحد']) {
      expect(
        resolver.resolve(phrase, referenceLocal: reference),
        DateTime(2026, 8, 9),
        reason: phrase,
      );
    }
  });

  test('unresolved or genuinely absent date returns null', () {
    expect(resolver.resolve('في وقت ما', referenceLocal: reference), isNull);
  });

  test('an explicit date wins over relative and message calendar dates', () {
    for (final phrase in [
      'Yesterday I logged weight for 2026-03-01',
      'سجل وزني أمس بتاريخ ٢٠٢٦-٠٣-٠١',
      'اليوم ۲۰۲۶/۰۳/۰۱ وزني 82',
      'Log weight on 1 March 2026, not yesterday',
      'سجل يوم ١ مارس ٢٠٢٦ بدل أمس',
    ]) {
      expect(
        resolver.resolve(phrase, referenceLocal: reference),
        DateTime(2026, 3, 1),
        reason: phrase,
      );
    }
  });

  test('invalid or conflicting explicit dates never fall back to today', () {
    for (final phrase in [
      'today 2026-02-30',
      'yesterday 2026-13-01',
      'today 2026-03-01 and 2026-03-02',
    ]) {
      expect(
        resolver.resolve(phrase, referenceLocal: reference),
        isNull,
        reason: phrase,
      );
    }
    expect(
      resolver.resolve('today 2028-02-29', referenceLocal: reference),
      DateTime(2028, 2, 29),
    );
  });

  test(
    'relative days keep local midnight across daylight clock transitions',
    () {
      for (final date in [
        DateTime(2026, 10, 5, 12),
        DateTime(2026, 4, 6, 12),
        DateTime(2026, 3, 9, 12),
        DateTime(2026, 11, 2, 12),
      ]) {
        final yesterday = resolver.resolve('yesterday', referenceLocal: date);
        expect(yesterday, DateTime(date.year, date.month, date.day - 1));
        expect(yesterday?.hour, 0);
      }
    },
  );
}
