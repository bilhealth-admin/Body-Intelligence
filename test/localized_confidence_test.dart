import 'package:body_intelligence_log/engine/personal_baseline_engine.dart';
import 'package:body_intelligence_log/features/analytics/localized_confidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Personal Baseline confidence never leaks enum names into Arabic', () {
    const expected = {
      BaselineConfidence.insufficient: 'غير كافية',
      BaselineConfidence.low: 'منخفضة',
      BaselineConfidence.medium: 'متوسطة',
      BaselineConfidence.high: 'مرتفعة',
    };
    for (final entry in expected.entries) {
      final label = localizedBaselineConfidence(entry.key, arabic: true);
      expect(label, entry.value);
      expect(label, isNot(entry.key.name));
    }
  });
}
