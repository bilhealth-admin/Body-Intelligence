import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog covers every literal used by the onboarding UI', () async {
    final page = await _librarySource(
      'lib/features/onboarding/onboarding_page.dart',
    );
    final scaffold = await File(
      'lib/features/onboarding/widgets/modern_onboarding_scaffold.dart',
    ).readAsString();
    final sourceKeys = <String>{
      ..._extract(page, RegExp(r"\bt\(\s*'((?:\\.|[^'])*)'", multiLine: true)),
      ..._extract(
        scaffold,
        RegExp(r"_copy\(context,\s*'((?:\\.|[^'])*)'", multiLine: true),
      ),
    };

    expect(sourceKeys, isNotEmpty);
    final missing = sourceKeys.difference(OnboardingRuntimeCopy.englishKeys);
    expect(
      missing,
      isEmpty,
      reason: 'OnboardingRuntimeCopy is missing UI literals: $missing',
    );
  });

  test('all 25 production locales have non-empty complete onboarding copy', () {
    final expectedTags = <String>{'en', ...BilLocalePolicy.productionTags};
    expect(OnboardingRuntimeCopy.supportedTags, expectedTags);

    for (final tag in expectedTags) {
      expect(
        OnboardingRuntimeCopy.coversTag(tag),
        isTrue,
        reason: 'Missing onboarding translation for $tag',
      );
    }
    for (final entry in OnboardingRuntimeCopy.values.entries) {
      expect(entry.value.keys.toSet(), expectedTags, reason: entry.key);
      expect(
        entry.value.values.every((value) => value.trim().isNotEmpty),
        isTrue,
        reason: entry.key,
      );
    }
  });

  test('non-English catalogs are translated and contain no mojibake', () {
    final broken = RegExp(r'Ã|Â|â€|Ø|Ù');
    for (final tag in BilLocalePolicy.productionTags.where(
      (value) => value != 'en',
    )) {
      final translated = OnboardingRuntimeCopy.values.entries
          .where((entry) => entry.value[tag] != entry.key)
          .length;
      expect(
        translated,
        greaterThan(OnboardingRuntimeCopy.values.length * .85),
        reason: '$tag is mostly an English fallback',
      );
      expect(
        OnboardingRuntimeCopy.values.values.any(
          (translations) => broken.hasMatch(translations[tag]!),
        ),
        isFalse,
        reason: '$tag contains malformed UTF-8',
      );
    }
  });
}

Future<String> _librarySource(String path) async {
  final library = File(path);
  final entrypoint = await library.readAsString();
  final parts = RegExp(r"part '([^']+)';")
      .allMatches(entrypoint)
      .map((match) => File('${library.parent.path}/${match.group(1)!}'));
  return <String>[
    entrypoint,
    for (final part in parts) await part.readAsString(),
  ].join('\n');
}

Set<String> _extract(String source, RegExp pattern) => pattern
    .allMatches(source)
    .map((match) => _unescape(match.group(1)!))
    .toSet();

String _unescape(String value) => value
    .replaceAll(r"\'", "'")
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\\', r'\');
