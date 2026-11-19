import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sources = [
    'The previous request was refunded without using credits. Tap Retry request to send it again.',
    'Retry request',
    'This request needs access to {category}. Review this category in Coach settings. Nothing was changed.',
    'Coach actions are set to Read only. Review permissions in Coach settings. Nothing was changed.',
    'Coach settings',
    'Nutrition and meals',
    'Training and activity',
    'Sleep, fasting and habits',
    'Progress analytics',
  ];
  for (final tag in BilLocalePolicy.productionTags) {
    test(
      'Coach request and capability recovery has authored copy for $tag',
      () {
        for (final source in sources) {
          final translated = RuntimeCopy.resolve(source, tag);
          expect(translated, isNotNull, reason: '$tag: $source');
          expect(translated!.trim(), isNotEmpty);
          if (source.contains('{category}')) {
            expect(translated, contains('{category}'));
          }
        }
      },
    );
  }
}
