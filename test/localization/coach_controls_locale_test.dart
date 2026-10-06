import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_coach_controls.dart';
import 'package:body_intelligence_log/features/intelligence_center/intelligence_locale_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Coach controls and existing consent copy resolve through all 25 locales',
    () {
      expect(
        CoachControlsRuntimeCopy.rows.keys.toSet(),
        BilLocalePolicy.productionTags,
      );
      final sources = CoachControlsRuntimeCopy.sources;
      final arabic = CoachControlsRuntimeCopy.rows['ar']!;
      for (final tag in BilLocalePolicy.productionTags) {
        final row = CoachControlsRuntimeCopy.rows[tag]!;
        expect(row.length, sources.length, reason: tag);
        for (var i = 0; i < sources.length; i++) {
          final source = sources[i];
          final translated = row[i];
          final reason = '$tag: $source';
          expect(translated.trim(), isNotEmpty, reason: reason);
          if (tag != 'en') {
            expect(translated, isNot(source), reason: reason);
          }
          expect(RuntimeCopy.resolve(source, tag), translated, reason: reason);
          expect(
            intelligenceTextFor(tag, source, arabic[i]),
            translated,
            reason: 'actual Coach tr resolver: $reason',
          );
          for (final token in ['BIL', 'Google', 'Gemini', '12']) {
            if (source.contains(token)) {
              expect(translated, contains(token), reason: reason);
            }
          }
        }
      }
    },
  );

  test('read-only, confirmation and write modes retain distinct labels', () {
    for (final tag in BilLocalePolicy.productionTags) {
      final labels = [
        for (final source in ['Read only', 'Ask before write', 'Write allowed'])
          CoachControlsRuntimeCopy.resolve(source, tag),
      ];
      expect(labels, everyElement(isNotNull), reason: tag);
      expect(labels.toSet(), hasLength(3), reason: tag);
    }
  });
}
