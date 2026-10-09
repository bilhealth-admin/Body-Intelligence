import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_quality_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publishing and cached Coach status never fall back to English', () {
    expect(QualityFeedbackRuntimeCopy.balanced, isTrue);
    expect(QualityFeedbackRuntimeCopy.sources, hasLength(2));
    for (final tag in BilLocalePolicy.productionTags) {
      for (final source in QualityFeedbackRuntimeCopy.sources) {
        final expected = QualityFeedbackRuntimeCopy.resolve(source, tag);
        expect(expected, isNotNull, reason: '$tag: $source');
        expect(expected!.trim(), isNotEmpty);
        expect(RuntimeCopy.resolve(source, tag), expected);
        if (tag != 'en') {
          expect(expected, isNot(source), reason: '$tag: $source');
        }
      }
    }
  });
}
