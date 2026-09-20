import 'package:body_intelligence_log/features/daily_log/presentation/macro_value_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macro formatter rounds only the displayed gram value', () {
    expect(formatDiaryMacroGrams(14), '14');
    expect(formatDiaryMacroGrams(.2), '0');
    expect(formatDiaryMacroGrams(.6), '1');
    expect(formatDiaryMacroGrams(12.64), '13');
    expect(formatDiaryMacroGrams(double.nan), '—');
  });
}
