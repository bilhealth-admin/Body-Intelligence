import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_release_closure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/localization/locale_fallback_closure.dart';

void main() {
  test('all tracked 25-locale surfaces close English fallback paths', () async {
    final result = await auditLocaleFallbackClosure();
    expect(result.requiredSourceCount, greaterThanOrEqualTo(578));
    expect(result.missingSources, isEmpty);
    expect(result.directFallbackFiles, isEmpty);
    expect(result.androidFailures, isEmpty);
    expect(result.passed, isTrue);
  });

  test('release closure is complete, translated, and placeholder-safe', () {
    expect(ReleaseClosureRuntimeCopy.balanced, isTrue);
    expect(
      ReleaseClosureRuntimeCopy.supported,
      BilLocalePolicy.productionTags.toSet(),
    );

    for (final source in ReleaseClosureRuntimeCopy.sources) {
      final expectedPlaceholders = RegExp(
        r'\{[^}]+\}',
      ).allMatches(source).map((match) => match.group(0)).toList();
      for (final tag in BilLocalePolicy.productionTags) {
        final translated = ReleaseClosureRuntimeCopy.resolve(source, tag);
        expect(translated, isNotNull, reason: '$tag: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $source');
        if (tag != 'en') {
          expect(translated, isNot(source), reason: '$tag: $source');
        }
        final actualPlaceholders = RegExp(
          r'\{[^}]+\}',
        ).allMatches(translated).map((match) => match.group(0)).toList();
        expect(
          actualPlaceholders,
          expectedPlaceholders,
          reason: '$tag: $source',
        );
        if (source.contains('BIL')) {
          expect(translated, contains('BIL'), reason: '$tag: $source');
        }
        if (source.contains('Gemini')) {
          expect(translated, contains('Gemini'), reason: '$tag: $source');
        }
      }
    }
  });

  test('Gemini remains a product name in every release locale', () {
    const source =
        'Gemini detects the spoken language automatically and answers in it. Audio is used for that request only and is not saved.';
    const zodiacMistranslations = <String>[
      'মিথুন',
      'ราศีเมถุน',
      'Zwillinge',
      'Gemelli',
      'Gêmeos',
      'Gémeos',
      'جوزا',
      'मिथुन',
      '双子座',
      '雙子座',
      'Близнец',
      'Song Tử',
      'Близнюки',
    ];

    for (final tag in BilLocalePolicy.productionTags) {
      final copy = RuntimeCopy.resolve(source, tag) ?? source;
      expect(copy, contains('Gemini'), reason: tag);
      for (final zodiac in zodiacMistranslations) {
        expect(copy, isNot(contains(zodiac)), reason: '$tag: $zodiac');
      }
    }
  });
}
