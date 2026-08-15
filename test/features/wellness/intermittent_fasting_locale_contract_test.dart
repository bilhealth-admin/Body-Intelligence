import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'intermittent fasting surface has direct copy in every extended locale',
    () {
      const keys = <String>{
        'Intermittent fasting',
        'Intermittent fasting with BIL',
        'Intermittent fast in progress',
        'Start intermittent fast',
        'End intermittent fast',
        'Intermittent fasting history',
        'Intermittent fasting check-in',
        'Return after 24 hours',
      };

      expect(RuntimeCopy.supported, hasLength(25));
      for (final key in keys) {
        for (final locale in ExtendedRuntimeCopy.supported) {
          expect(
            ExtendedRuntimeCopy.values[key]?.containsKey(locale),
            isTrue,
            reason: 'missing direct catalog entry $locale/$key',
          );
          expect(
            ExtendedRuntimeCopy.values[key]![locale]!.trim(),
            isNotEmpty,
            reason: 'empty direct catalog entry $locale/$key',
          );
        }
      }
    },
  );
}
