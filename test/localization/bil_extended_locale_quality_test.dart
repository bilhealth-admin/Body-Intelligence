import 'package:body_intelligence_log/app/localization/bil_extended_locale_quality.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('20 extended catalogs cover the complete runtime surface', () {
    final report = BilExtendedLocaleQuality.audit();
    expect(report.catalogCount, 20);
    expect(report.keyCount, greaterThanOrEqualTo(270));
    expect(report.errors, isEmpty, reason: report.errors.take(20).join('\n'));
    expect(report.passed, isTrue);
    expect(RuntimeCopy.balanced, isTrue);
    expect(ExtendedRuntimeCopy.values, hasLength(report.keyCount));
  });
}
