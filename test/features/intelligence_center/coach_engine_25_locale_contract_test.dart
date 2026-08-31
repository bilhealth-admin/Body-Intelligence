import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_health_glossary.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/intelligence_locale_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every literal engine reply resolves outside English in 25 locales', () {
    final source = File(
      'lib/features/intelligence_center/services/intelligence_center_engine.dart',
    ).readAsStringSync();
    final englishSources = RegExp(
      r"\btr\(\s*'((?:\\.|[^'])*)'\s*,",
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1)!).toSet();
    expect(englishSources, isNotEmpty);

    // Product names are canonical commerce identifiers, not untranslated
    // prose. Translator review intentionally keeps names such as
    // "Premium AI Coach" unchanged in several locales.
    final productNames = BilHealthGlossary.terms
        .where((term) => term.domain == BilGlossaryDomain.commerce)
        .map((term) => term.english)
        .toSet();

    final missing = <String>[];
    for (final tag in BilLocalePolicy.productionTags) {
      if (tag == 'en') continue;
      for (final english in englishSources) {
        if (productNames.contains(english)) continue;
        final resolved = intelligenceTextFor(tag, english, 'نص عربي');
        if (resolved == english) missing.add('$tag: $english');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
