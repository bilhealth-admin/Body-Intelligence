import 'package:body_intelligence_log/app/localization/bil_locale_names.dart';
import 'package:body_intelligence_log/features/auth/auth_entry_locale_copy.dart';
import 'package:body_intelligence_log/features/auth/auth_five_locale_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 25 declared locales have complete exact auth copy', () {
    const declared = BilLocaleNames.native;
    expect(declared.length, 25);
    expect(authEntryAuthoredLocaleTags, unorderedEquals(declared.keys));

    for (final localeTag in declared.keys) {
      expect(
        authEntryHasExactLocale(localeTag),
        isTrue,
        reason: 'Missing locale $localeTag',
      );
      for (final key in AuthEntryCopyKey.values) {
        expect(
          authEntryHasExactCopy(localeTag, key),
          isTrue,
          reason: 'Missing $localeTag / $key',
        );
        final value = authEntryTextForTag(localeTag, key);
        expect(value.trim(), isNotEmpty, reason: '$localeTag / $key');
        if (localeTag != 'en') {
          expect(
            value,
            isNot(authEntryTextForTag('en', key)),
            reason: 'English fallback: $localeTag / $key',
          );
        }
      }
    }
  });

  test('regional and script locale tags stay distinct', () {
    expect(authEntryHasExactLocale('pt-BR'), isTrue);
    expect(authEntryHasExactLocale('pt-PT'), isTrue);
    expect(authEntryHasExactLocale('zh-Hans'), isTrue);
    expect(authEntryHasExactLocale('zh-Hant'), isTrue);
    expect(
      authEntryTextForTag('pt-BR', AuthEntryCopyKey.taglineTitle),
      isNot(authEntryTextForTag('pt-PT', AuthEntryCopyKey.taglineTitle)),
    );
    expect(
      authEntryTextForTag('zh-Hans', AuthEntryCopyKey.signIn),
      isNot(authEntryTextForTag('zh-Hant', AuthEntryCopyKey.signIn)),
    );
  });

  test('dynamic email and countdown copy uses stable placeholders', () {
    const email = 'person@example.com';
    const clock = '00:42';
    for (final localeTag in BilLocaleNames.native.keys) {
      final sent = authEntryCodeSentForTag(localeTag, email);
      final countdown = authEntryResendCountdownForTag(localeTag, clock);
      expect(sent, contains(email), reason: localeTag);
      expect(countdown, contains(clock), reason: localeTag);
      expect(sent, isNot(contains('{email}')), reason: localeTag);
      expect(countdown, isNot(contains('{time}')), reason: localeTag);
    }
  });

  test('dedicated reviewer route has native guidance in every locale', () {
    for (final localeTag in BilLocaleNames.native.keys) {
      for (final copy in const [
        ('Store reviewer access', 'دخول مراجع المتجر'),
        (
          'Use only the dedicated credentials supplied in the store review notes.',
          'استخدم فقط بيانات المراجع المخصصة والموجودة في ملاحظات مراجعة المتجر.',
        ),
      ]) {
        final value = authFiveLocaleTextFor(localeTag, copy.$1, copy.$2);
        expect(value.trim(), isNotEmpty, reason: '$localeTag / ${copy.$1}');
        if (localeTag != 'en') {
          expect(value, isNot(copy.$1), reason: 'English fallback: $localeTag');
        }
      }
    }
  });
}
