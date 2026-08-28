import 'package:body_intelligence_log/features/daily_log/presentation/macro_value_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macro formatter preserves meaningful decimal grams', () {
    expect(formatDiaryMacroGrams(14), '14');
    expect(formatDiaryMacroGrams(.2), '0.2');
    expect(formatDiaryMacroGrams(.3), '0.3');
    expect(formatDiaryMacroGrams(12.64), '12.6');
    expect(formatDiaryMacroGrams(double.nan), '—');
  });
}
