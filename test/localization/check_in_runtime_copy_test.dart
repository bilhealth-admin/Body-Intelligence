import 'package:body_intelligence_log/app/localization/runtime_copy_check_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('check-in and diet reset copy is direct in all 25 locales', () {
    expect(CheckInRuntimeCopy.supported, hasLength(25));
    expect(CheckInRuntimeCopy.balanced, isTrue);
    for (final entry in CheckInRuntimeCopy.values.entries) {
      for (final locale in CheckInRuntimeCopy.supported) {
        final value = CheckInRuntimeCopy.resolve(entry.key, locale);
        expect(value, isNotNull, reason: '$locale: ${entry.key}');
        expect(value!.trim(), isNotEmpty, reason: '$locale: ${entry.key}');
        if (locale != 'en') {
          expect(value, isNot(entry.key), reason: '$locale: ${entry.key}');
        }
      }
    }
  });
}
