import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/localization/smart_plan_copy_sources.dart';

void main() {
  test('Smart Plan copy keeps the runtime lookup map valid and unique', () {
    final keys = RuntimeCopy.values.keys.toList();
    final counts = <String, int>{};
    for (final key in keys) {
      counts[key] = (counts[key] ?? 0) + 1;
    }
    expect(counts.entries.where((e) => e.value > 1).map((e) => e.key), isEmpty);
    expect(RuntimeCopy.resolve('My Smart Plan', 'fr'), isNotEmpty);
  });
  test(
    'all Smart Plan labels, disclosures and confirmation copy cover 25 locales',
    () async {
      final sources = await smartPlanCopySources();
      expect(sources.length, greaterThan(100));
      expect(
        sources,
        containsAll([
          'My Smart Plan',
          'No HealthKit writes, food logging, or AI submission occurs when preparing a draft.',
          'I am 18 or older and reviewed my allergies, dietary restrictions and training availability.',
          'Warm up before your session',
          'Continue to exercises',
          'The reference could not be opened. Try again.',
          'Uses the released BIL Gym plan with its source warm-up, sets, repetitions and rest. Review the draft before activating it.',
        ]),
      );
      for (final source in sources) {
        for (final tag in BilLocalePolicy.productionTags) {
          final translation = RuntimeCopy.resolve(source, tag);
          expect(translation, isNotNull, reason: '$tag: $source');
          expect(translation!.trim(), isNotEmpty, reason: '$tag: $source');
        }
      }
    },
  );
}
