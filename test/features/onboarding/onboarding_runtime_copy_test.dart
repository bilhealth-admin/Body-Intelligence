import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goal timing uses clear customer-facing wording', () {
    const expected = <String, String>{
      'en': 'Expected time to goal',
      'ar': 'الوقت المتوقع للوصول إلى الهدف',
      'fr': 'Temps estimé pour atteindre l’objectif',
      'es': 'Tiempo estimado para alcanzar el objetivo',
      'tr': 'Hedefe ulaşmak için tahmini süre',
      'de': 'Voraussichtliche Zeit bis zum Ziel',
      'it': "Tempo previsto per raggiungere l'obiettivo",
      'pt-BR': 'Tempo estimado para alcançar a meta',
      'pt-PT': 'Tempo estimado para atingir o objetivo',
      'ur': 'ہدف تک پہنچنے کا متوقع وقت',
      'fa': 'زمان مورد انتظار برای رسیدن به هدف',
      'hi': 'लक्ष्य तक पहुँचने का अनुमानित समय',
      'id': 'Perkiraan waktu untuk mencapai target',
      'ms': 'Anggaran masa untuk mencapai sasaran',
      'ja': '目標達成までの予想時間',
      'ko': '목표 달성까지 예상 시간',
      'zh-Hans': '达成目标的预计时间',
      'zh-Hant': '達成目標的預計時間',
      'ru': 'Ожидаемое время достижения цели',
      'bn': 'লক্ষ্য অর্জনের আনুমানিক সময়',
      'vi': 'Thời gian dự kiến để đạt mục tiêu',
      'th': 'ระยะเวลาที่คาดว่าจะถึงเป้าหมาย',
      'pl': 'Przewidywany czas do osiągnięcia celu',
      'nl': 'Verwachte tijd om je doel te bereiken',
      'uk': 'Очікуваний час досягнення цілі',
    };
    expect(
      OnboardingRuntimeCopy.englishKeys,
      contains('Expected time to goal'),
    );
    expect(
      OnboardingRuntimeCopy.englishKeys,
      isNot(contains('Estimated target window')),
    );
    expect(OnboardingRuntimeCopy.values['Expected time to goal'], expected);
  });

  test('plan step does not expose implementation-source copy', () async {
    final page = await _librarySource(
      'lib/features/onboarding/onboarding_page.dart',
    );
    expect(page, isNot(contains('Source: Mifflin')));
  });

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
