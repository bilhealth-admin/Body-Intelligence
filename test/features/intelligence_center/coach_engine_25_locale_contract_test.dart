import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_health_glossary.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/intelligence_locale_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
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
  // Exercise the actual reply branch, locale resolver, source selection and
  // template replacement; these are not catalog-to-catalog equality tests.
  for (final tag in BilLocalePolicy.productionTags) {
    test(
      'actual Coach calorie sources and values stay localized $tag',
      () async {
        await _verifyCalorieSources(tag);
      },
    );
  }
  for (final tag in const ['pt_BR', 'pt_PT', 'zh_Hans', 'zh_Hant']) {
    test(
      'actual Coach calorie source preserves canonical variant $tag',
      () async {
        await _verifyCalorieSources(tag);
      },
    );
  }
}

Future<void> _verifyCalorieSources(String tag) async {
  const scenarios =
      <({double value, String source, String english, String arabic})>[
        (
          value: 1800,
          source: 'scheduled_daily_goal',
          english: "It comes from today's scheduled calorie goal.",
          arabic: 'مصدره هدف سعرات اليوم المجدول.',
        ),
        (
          value: 1000,
          source: 'saved_percentage_goal',
          english: 'It comes from the calorie goal saved in Nutrition Goals.',
          arabic: 'مصدره هدف السعرات المحفوظ في أهداف التغذية.',
        ),
        (
          value: 1980,
          source: 'body_profile_calculation',
          english: 'It comes from the current BIL body-profile calculation.',
          arabic: 'مصدره حساب BIL الحالي المبني على ملف جسمك.',
        ),
      ];
  for (final scenario in scenarios) {
    final context = CoachContextSnapshot(
      generatedAt: DateTime.utc(2026, 10, 13),
      profile: const {},
      weights: const [],
      nutritionDays: const [],
      waterHistory: const [],
      computedHealth: {
        'dailyTargets': {'caloriesKcal': scenario.value},
        'dailyTargetSources': {'caloriesKcal': scenario.source},
      },
    );
    final reply = await const IntelligenceCenterEngine().answer(
      question: 'calories',
      arabic: tag == 'ar',
      localeCode: tag,
      // A legitimate language hint exercises the same localized answer used
      // by voice input. This does not claim natural-language intent coverage.
      detectedLanguageTag: tag,
      coachContext: context,
    );
    final value = scenario.value.toInt().toString();
    final sourceCopy = intelligenceTextFor(
      tag,
      scenario.english,
      scenario.arabic,
    );
    expect(
      reply.message.text,
      contains(value),
      reason: '$tag ${scenario.source}',
    );
    expect(
      reply.message.text,
      contains(sourceCopy),
      reason: '$tag ${scenario.source}',
    );
    expect(reply.message.evidence, contains('dailyTargets.caloriesKcal'));
    expect(reply.message.evidence, contains(scenario.source));
    expect(reply.actions, isEmpty);
    expect(reply.usedExternalKnowledge, isFalse);
    expect(reply.message.text, isNot(contains('{value}')));
    expect(reply.message.text, isNot(contains('{source}')));
    for (final other in scenarios.where((s) => s.source != scenario.source)) {
      expect(reply.message.evidence, isNot(contains(other.source)));
      expect(
        reply.message.text,
        isNot(contains(intelligenceTextFor(tag, other.english, other.arabic))),
      );
    }
    if (tag != 'en') {
      expect(
        sourceCopy,
        isNot(scenario.english),
        reason: '$tag source fallback',
      );
      expect(
        reply.message.text,
        isNot(contains('Your current daily target is')),
        reason: '$tag template fallback',
      );
      expect(
        reply.message.text,
        isNot(contains('It comes from')),
        reason: '$tag source fallback',
      );
    }
  }
}
