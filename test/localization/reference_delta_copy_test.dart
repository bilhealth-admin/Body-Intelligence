import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_reference_delta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reference delta is complete for all 25 production locales', () {
    expect(ReferenceDeltaRuntimeCopy.sources, hasLength(17));
    expect(ReferenceDeltaRuntimeCopy.balanced, isTrue);
    expect(
      ReferenceDeltaRuntimeCopy.supported,
      BilLocalePolicy.productionTags.toSet(),
    );

    for (final tag in BilLocalePolicy.productionTags) {
      for (final source in ReferenceDeltaRuntimeCopy.sources) {
        final copy = ReferenceDeltaRuntimeCopy.resolve(source, tag);
        expect(copy, isNotNull, reason: '$tag: $source');
        expect(copy!.trim(), isNotEmpty, reason: '$tag: $source');
        expect(RuntimeCopy.resolve(source, tag), copy);
        if (tag != 'en') {
          expect(copy, isNot(source), reason: '$tag: $source');
        }
        if (source.contains('BIL')) {
          expect(copy, contains('BIL'), reason: '$tag: $source');
        }
        final placeholders = RegExp(r'\{[^}]+\}');
        expect(
          placeholders.allMatches(copy).map((match) => match.group(0)),
          placeholders.allMatches(source).map((match) => match.group(0)),
          reason: '$tag: $source',
        );
      }
    }
  });

  test('locale aliases retain language and script, with no invented fallback', () {
    const source = 'Creator rewards';
    for (final alias in const {
      'pt_BR': 'pt-BR',
      'pt_PT': 'pt-PT',
      'zh_Hans': 'zh-Hans',
      'zh_Hant': 'zh-Hant',
    }.entries) {
      expect(
        ReferenceDeltaRuntimeCopy.resolve(source, alias.key),
        ReferenceDeltaRuntimeCopy.resolve(source, alias.value),
      );
    }
    expect(ReferenceDeltaRuntimeCopy.resolve('Unknown source', 'en'), isNull);
    expect(ReferenceDeltaRuntimeCopy.resolve(source, 'xx'), isNull);
  });
}
