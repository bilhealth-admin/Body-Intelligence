import 'package:body_intelligence_log/app/localization/runtime_copy_coach_recovery.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_current_release.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/intelligence_locale_copy.dart';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_ai_safety_reports.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_community_moderation.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_community_social.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_coach_review.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_platform_conversation.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_release_closure.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_sleep_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/localization/locale_fallback_closure.dart';

void main() {
  test('current release labels and existing recovery copy cover all 25 locales', () {
    expect(CurrentReleaseRuntimeCopy.balanced, isTrue);
    expect(CurrentReleaseRuntimeCopy.sources, const [
      'Allow friend requests',
      'Who can see my profile',
      'Your reviewed estimates were saved.',
      'Import steps, distance and active energy from Health Connect when available.',
    ]);
    expect(
      CurrentReleaseRuntimeCopy.supported,
      BilLocalePolicy.productionTags.toSet(),
    );
    const recoverySources = [
      'Coach actions are set to Read only. Review permissions in Coach settings. Nothing was changed.',
      'Nutrition and meals',
      'Progress analytics',
      'Retry request',
      'Sleep, fasting and habits',
      'The previous request was refunded without using credits. Tap Retry request to send it again.',
      'This request needs access to {category}. Review this category in Coach settings. Nothing was changed.',
      'Training and activity',
    ];
    final placeholders = RegExp(r'\{[^}]+\}');
    for (final tag in BilLocalePolicy.productionTags) {
      for (final source in [
        ...CurrentReleaseRuntimeCopy.sources,
        ...recoverySources,
      ]) {
        final translated = RuntimeCopy.resolve(source, tag);
        expect(translated, isNotNull, reason: '$tag: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $source');
        if (tag != 'en') {
          expect(translated, isNot(source), reason: '$tag: $source');
        }
        expect(
          placeholders.allMatches(translated).map((match) => match[0]).toSet(),
          placeholders.allMatches(source).map((match) => match[0]).toSet(),
          reason: '$tag preserves placeholders: $source',
        );
        if (recoverySources.contains(source)) {
          expect(translated, CoachRecoveryRuntimeCopy.resolve(source, tag));
        } else {
          expect(translated, CurrentReleaseRuntimeCopy.resolve(source, tag));
        }
      }
    }
    expect(
      CurrentReleaseRuntimeCopy.resolve('Not a catalog source', 'ar'),
      isNull,
    );
    expect(
      CurrentReleaseRuntimeCopy.resolve(
        CurrentReleaseRuntimeCopy.sources.first,
        'zz',
      ),
      isNull,
    );
  });

  test(
    'Android brand exception applies only to the exact canonical app name',
    () {
      expect(
        androidResourceValueIssue(
          'app_name',
          'Body Intelligence Log',
          'Body Intelligence Log',
        ),
        isNull,
      );
      for (final invalidBrand in [
        'BIL',
        'Body Intelligence Log ',
        'سجل ذكاء الجسم',
      ]) {
        expect(
          androidResourceValueIssue(
            'app_name',
            invalidBrand,
            'Body Intelligence Log',
          ),
          'canonical_brand_mismatch',
        );
      }
      for (final key in [
        'health_permissions_rationale_title',
        'health_permissions_rationale_body',
        'health_permissions_privacy_policy_action',
        'any_other_key',
      ]) {
        expect(
          androidResourceValueIssue(key, 'English copy', 'English copy'),
          'english_fallback',
        );
        expect(
          androidResourceValueIssue(key, ' نص مترجم ', 'English copy'),
          isNull,
        );
        expect(androidResourceValueIssue(key, null, 'English copy'), 'missing');
        expect(androidResourceValueIssue(key, '  ', 'English copy'), 'missing');
      }
      expect(
        androidResourceValueIssue('app_name', null, 'Body Intelligence Log'),
        'missing',
      );
    },
  );

  test('Coach waiting, copy, recovery and feed labels cover every locale', () {
    const sources = [
      'Preparing your reply…',
      'Working on your question…',
      'Thanks for waiting…',
      'Copy message',
      'Loading posts',
      'AI Coach could not complete the reply. Your question remains in this chat; review any earlier actions before retrying.',
      'Subscription check unavailable',
    ];
    for (final tag in BilLocalePolicy.productionTags) {
      expect(
        communityTextForLanguage(tag, 'Loading posts', 'تحميل المنشورات'),
        RuntimeCopy.resolve('Loading posts', tag),
        reason: 'Feed adapter: $tag',
      );
      for (final source in sources.take(4)) {
        expect(
          intelligenceTextFor(tag, source, RuntimeCopy.resolve(source, 'ar')!),
          RuntimeCopy.resolve(source, tag),
          reason: 'Coach adapter: $tag: $source',
        );
      }
    }
    for (final source in sources) {
      for (final tag in BilLocalePolicy.productionTags) {
        final translated = RuntimeCopy.resolve(source, tag);
        expect(translated, isNotNull, reason: '$tag: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $source');
        if (tag != 'en') {
          expect(translated, isNot(source), reason: '$tag: $source');
        }
      }
    }
  });

  test(
    'Coach literal audit includes new part helpers and Dart quote forms',
    () {
      expect(
        coachLiteralRuntimeSources(r'''
        tr('Saved result.', 'نتيجة محفوظة.');
        tr("Review your data.", 'راجع بياناتك.');
        tr('First line. ' 'Second line.', 'سطران.');
        tr('Coach\'s reply', 'إجابة المدرب');
        tr(r'Literal $token', 'نص حرفي');
        tr('Runtime $value', 'قيمة');
        tr('Runtime ${value.count}', 'قيمة');
        tr('Escaped \$token', 'رمز');
      '''),
        {
          'Saved result.',
          'Review your data.',
          'First line. Second line.',
          "Coach's reply",
          r'Literal $token',
          r'Escaped $token',
        },
      );
    },
  );

  test('all tracked 25-locale surfaces close English fallback paths', () async {
    final result = await auditLocaleFallbackClosure();
    expect(
      AiSafetyReportRuntimeCopy.balanced,
      isTrue,
      reason: AiSafetyReportRuntimeCopy.validationIssues.join('\n'),
    );
    expect(result.requiredSourceCount, greaterThanOrEqualTo(578));
    expect(result.missingSources, isEmpty, reason: jsonEncode(result.toJson()));
    expect(result.directFallbackFiles, isEmpty);
    expect(result.androidFailures, isEmpty);
    expect(result.passed, isTrue);
  });

  test('AI Coach answer actions stay descriptive in all 25 app locales', () {
    expect(CoachReviewRuntimeCopy.balanced, isTrue);
    for (final tag in BilLocalePolicy.productionTags) {
      for (final source in CoachReviewRuntimeCopy.answerActionKeys) {
        final translated = CoachReviewRuntimeCopy.resolve(source, tag);
        expect(translated, isNotNull, reason: '$tag: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $source');
        expect(RuntimeCopy.resolve(source, tag), translated);
        if (tag != 'en') {
          expect(translated, isNot(source), reason: '$tag: $source');
        }
      }
    }
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

  test('platform and conversation labels close all 25 locale paths', () {
    expect(PlatformConversationRuntimeCopy.balanced, isTrue);
    expect(
      PlatformConversationRuntimeCopy.supported,
      BilLocalePolicy.productionTags,
    );

    for (final tag in BilLocalePolicy.productionTags) {
      for (final source in PlatformConversationRuntimeCopy.sources) {
        final translated = PlatformConversationRuntimeCopy.resolve(source, tag);
        expect(translated, isNotNull, reason: '$tag: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $source');
        expect(RuntimeCopy.resolve(source, tag), translated);
        if (tag != 'en' &&
            source != PlatformConversationRuntimeCopy.appleHealth &&
            source != PlatformConversationRuntimeCopy.healthConnect) {
          expect(translated, isNot(source), reason: '$tag: $source');
        }
      }
      expect(
        PlatformConversationRuntimeCopy.resolve(
          PlatformConversationRuntimeCopy.appleHealth,
          tag,
        ),
        PlatformConversationRuntimeCopy.appleHealth,
      );
      expect(
        PlatformConversationRuntimeCopy.resolve(
          PlatformConversationRuntimeCopy.healthConnect,
          tag,
        ),
        PlatformConversationRuntimeCopy.healthConnect,
      );
    }
  });

  test('community moderation copy is native and placeholder-safe', () {
    expect(CommunityModerationRuntimeCopy.balanced, isTrue);
    expect(
      CommunityModerationRuntimeCopy.supported,
      BilLocalePolicy.productionTags.toSet(),
    );

    for (final tag in BilLocalePolicy.productionTags) {
      for (final source in CommunityModerationRuntimeCopy.sources) {
        final translated = CommunityModerationRuntimeCopy.resolve(source, tag);
        expect(translated, isNotNull, reason: '$tag: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $source');
        expect(RuntimeCopy.resolve(source, tag), translated);
        if (tag != 'en') {
          expect(translated, isNot(source), reason: '$tag: $source');
        }
        final sourcePlaceholders = RegExp(
          r'\{[^}]+\}',
        ).allMatches(source).map((match) => match.group(0)).toList();
        final translatedPlaceholders = RegExp(
          r'\{[^}]+\}',
        ).allMatches(translated).map((match) => match.group(0)).toList();
        expect(
          translatedPlaceholders,
          sourcePlaceholders,
          reason: '$tag: $source',
        );
      }
    }
  });

  test('community social copy is native and placeholder-safe', () {
    expect(CommunitySocialRuntimeCopy.balanced, isTrue);
    expect(
      CommunitySocialRuntimeCopy.supported,
      BilLocalePolicy.productionTags.toSet(),
    );

    for (final tag in BilLocalePolicy.productionTags) {
      for (final source in CommunitySocialRuntimeCopy.sources) {
        final translated = CommunitySocialRuntimeCopy.resolve(source, tag);
        expect(translated, isNotNull, reason: '$tag: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $source');
        expect(RuntimeCopy.resolve(source, tag), translated);
        if (tag != 'en') {
          expect(translated, isNot(source), reason: '$tag: $source');
        }
        final sourcePlaceholders = RegExp(
          r'\{[^}]+\}',
        ).allMatches(source).map((match) => match.group(0)).toList();
        final translatedPlaceholders = RegExp(
          r'\{[^}]+\}',
        ).allMatches(translated).map((match) => match.group(0)).toList();
        expect(
          translatedPlaceholders,
          sourcePlaceholders,
          reason: '$tag: $source',
        );
        for (final term in const ['BIL', 'iOS', 'Android']) {
          if (source.contains(term)) {
            expect(translated, contains(term), reason: '$tag: $source');
          }
        }
      }
    }
  });

  test('accessibility and wellness labels never fall back to English', () {
    for (final source in const [
      'Read answer aloud',
      'Wellness programs',
      'Verified workout video library',
    ]) {
      for (final tag in BilLocalePolicy.productionTags) {
        final translated = RuntimeCopy.resolve(source, tag);
        expect(translated, isNotNull, reason: '$tag: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $source');
        if (tag != 'en') {
          expect(translated, isNot(source), reason: '$tag: $source');
        }
        for (final marker in const ['Ã', 'Â', '�']) {
          expect(translated, isNot(contains(marker)), reason: '$tag: $source');
        }
      }
    }
  });

  test('sleep schedule copy is complete and placeholder-safe', () {
    expect(SleepScheduleRuntimeCopy.balanced, isTrue);
    for (final source in SleepScheduleRuntimeCopy.sources) {
      final expectedPlaceholders = RegExp(
        r'\{[^}]+\}',
      ).allMatches(source).map((match) => match.group(0)).toList();
      for (final tag in BilLocalePolicy.productionTags) {
        final translated = SleepScheduleRuntimeCopy.resolve(source, tag);
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
      }
    }
  });
}
