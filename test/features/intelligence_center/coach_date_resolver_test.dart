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
}
