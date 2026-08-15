import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/auth/auth_five_locale_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/intelligence_locale_copy.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/nutrition_copy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exact-tag feature helpers resolve extended locale copy', () {
    expect(
      authFiveLocaleTextFor(
        'zh-Hant',
        'Continue without an account',
        'المتابعة دون حساب',
      ),
      '無需帳戶即可繼續',
    );
    expect(
      intelligenceTextFor('pt-BR', 'Take action', '...'),
      isNot('Take action'),
    );
    expect(nutritionTextForLanguage('zh-Hans', 'Food', 'طعام'), isNot('Food'));
    expect(AppLocalizations.isRtl(const Locale('ur')), isTrue);
    expect(AppLocalizations.isRtl(const Locale('fa')), isTrue);
  });

  test('account gateway cloud status resolves directly in all 25 locales', () {
    const english = 'Cloud account is not enabled on this build.';
    const arabic = 'الحساب السحابي غير مفعّل في هذه النسخة.';
    for (final locale in AppLocalizations.supportedLocales) {
      final resolved = authFiveLocaleTextFor(
        locale.toLanguageTag(),
        english,
        arabic,
      );
      expect(resolved.trim(), isNotEmpty, reason: '$locale');
      if (locale.languageCode != 'en') {
        expect(
          resolved,
          isNot(english),
          reason: 'no English fallback: $locale',
        );
      }
    }
  });

  test('daily log summary resolves directly in every extended locale', () {
    for (final key in const [
      'Record your day',
      'Today’s recorded summary',
      'g protein',
      'ml water',
      'BIL shows only what you recorded and never fills missing values automatically.',
    ]) {
      for (final locale in AppLocalizations.supportedLocales.skip(5)) {
        final resolved = authFiveLocaleTextFor(
          locale.toLanguageTag(),
          key,
          key,
        );
        expect(resolved.trim(), isNotEmpty, reason: '$key / $locale');
        expect(resolved, isNot(key), reason: 'no English fallback: $locale');
      }
    }
  });

  test('primary release surfaces have direct extended-locale copy', () {
    const keys = <String>{
      'Weekly Digest',
      'Choose report week',
      'Food Insights',
      'See how your logged foods stack up this week.',
      'This week you logged:',
      'You logged in {days} out of 7 days.',
      'Logged',
      'No entry',
      'Premium insight active',
      'Unlock calorie insights',
      'No frequently logged foods yet. Log meals to build your weekly favorites.',
      'g carbs',
      'g fat',
      'No macro data logged',
      'Account & profile',
      'Diary & goals',
      'Privacy & notifications',
      'Health preferences',
      'Profile',
      'Diary Settings',
      'Sharing & Privacy',
      'BIL recipes',
      'Saved recipes',
      'Search recipes or tags',
      'All',
      'Calories',
      'Edit',
      'Goal',
      'Food',
      'Exercise',
      'Set a goal',
      'Set your calorie goal to track daily progress',
      'Steps',
      'Connect a source',
      'No activity logged',
      'Snacks count too—logging them makes the weekly picture honest.',
      '{visible} of {total} recipes',
      '{count} min',
      'Original · {language}',
      'Last 90 days',
      'Add weight to see your trend',
      'Last 30 days',
      'Connect or log steps to see your trend',
      'Copy to multiple days',
      'Copy previous day meals',
      'Save meal',
      'Plant-forward',
      'Save recipe',
      'Free',
      'Restore purchases',
      'Manage subscription',
      'Price unavailable on this device',
      'The purchase was not completed. No access was granted.',
      'Complete profile',
      'Complete your profile to calculate personalized targets.',
      'No body trend data recorded yet.',
      'No nutrition data recorded yet.',
      'No trend data recorded yet.',
    };
    final fallbacks = <String>[];
    const legitimateIdentity = <String>{
      '{count} min / it',
      '{count} min / ms',
      '{count} min / pl',
      '{count} min / nl',
      'Original · {language} / de',
      'Original · {language} / pt-BR',
      'Original · {language} / pt-PT',
    };
    for (final key in keys) {
      for (final locale in AppLocalizations.supportedLocales.skip(5)) {
        final resolved = RuntimeCopy.resolve(key, locale.toLanguageTag());
        final identity = '$key / ${locale.toLanguageTag()}';
        if (resolved == null ||
            resolved.trim().isEmpty ||
            (resolved == key && !legitimateIdentity.contains(identity))) {
          fallbacks.add(identity);
        }
      }
    }
    expect(fallbacks, isEmpty, reason: 'English/missing copy: $fallbacks');
  });

  test('zh-Hans health and action terminology is semantically exact', () {
    const expected = <String, String>{
      'Profile': '个人资料',
      'Steps': '步数',
      'Save meal': '保存餐食',
      'Plant-forward': '植物为主',
      'Save recipe': '保存食谱',
      'Free': '免费',
      'Restore purchases': '恢复购买',
      'Manage subscription': '管理订阅',
      'Body Twin': '身体孪生',
    };
    for (final entry in expected.entries) {
      expect(
        RuntimeCopy.resolve(entry.key, 'zh-Hans'),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('localized release templates preserve executable placeholders', () {
    const templates = <String, Set<String>>{
      '{visible} of {total} recipes': {'{visible}', '{total}'},
      '{count} min': {'{count}'},
      'Original · {language}': {'{language}'},
    };
    for (final entry in templates.entries) {
      for (final locale in AppLocalizations.supportedLocales.skip(5)) {
        final resolved = RuntimeCopy.resolve(
          entry.key,
          locale.toLanguageTag(),
        )!;
        for (final placeholder in entry.value) {
          expect(
            resolved,
            contains(placeholder),
            reason: '${entry.key} / $locale / $resolved',
          );
        }
      }
    }
  });
}
