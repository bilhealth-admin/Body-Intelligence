import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_smart_plan_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BIL-09 recovery copy covers all 25 locales', () {
    expect(SmartPlanRecoveryRuntimeCopy.sources, hasLength(6));
    expect(SmartPlanRecoveryRuntimeCopy.balanced, isTrue);
    for (final source in SmartPlanRecoveryRuntimeCopy.sources) {
      for (final tag in BilLocalePolicy.productionTags) {
        final native = SmartPlanRecoveryRuntimeCopy.resolve(source, tag);
        final context = '$tag: $source';
        expect(native, isNotNull, reason: context);
        expect(native!.trim(), isNotEmpty, reason: context);
        expect(RuntimeCopy.resolve(source, tag), native, reason: context);
        if (tag != 'en') {
          expect(native, isNot(source), reason: context);
        }
      }
    }
  });

  test('BIL-09 unknown recovery sources and locales do not resolve', () {
    final unknown = SmartPlanRecoveryRuntimeCopy.resolve('unknown', 'fr');
    expect(unknown, isNull);
    final source = SmartPlanRecoveryRuntimeCopy.sources.first;
    expect(SmartPlanRecoveryRuntimeCopy.resolve(source, 'xx'), isNull);
  });
}
