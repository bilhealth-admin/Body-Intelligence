import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_smart_plan_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BIL-09 recovery copy covers all 25 locales with no English fallback', () {
    expect(SmartPlanRecoveryRuntimeCopy.sources, hasLength(6));
    expect(SmartPlanRecoveryRuntimeCopy.balanced, isTrue);
    for (final source in SmartPlanRecoveryRuntimeCopy.sources) {
      for (final tag in BilLocalePolicy.productionTags) {
        final native = SmartPlanRecoveryRuntimeCopy.resolve(source, tag);
        expect(native, isNotNull, reason: '$tag: $source');
        expect(native!.trim(), isNotEmpty, reason: '$tag: $source');
        expect(RuntimeCopy.resolve(source, tag), native, reason: '$tag: $source');
        if (tag != 'en') {
          expect(native, isNot(source), reason: '$tag: $source');
        }
      }
    }
  });

  test('BIL-09 unlisted recovery keys and locales stay unrecognized', () {
    expect(SmartPlanRecoveryRuntimeCopy.resolve('not a recovery message', 'fr'), isNull);
    expect(SmartPlanRecoveryRuntimeCopy.resolve(
      SmartPlanRecoveryRuntimeCopy.sources.first, 'not-a-locale'), isNull);
  });
}
