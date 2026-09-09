import 'dart:ui' show TextDirection;

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/bil_written_language_resolver.dart';
import 'package:body_intelligence_log/features/community/presentation/community_chat_runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('friend-chat failure and privacy copy covers every extended locale', () {
    expect(CommunityChatRuntimeCopy.balanced, isTrue);
    final extended = BilLocalePolicy.productionTags.difference(const {
      'en',
      'ar',
      'fr',
      'es',
      'tr',
    });
    expect(extended, hasLength(20));
    for (final source in CommunityChatRuntimeCopy.sources) {
      for (final locale in extended) {
        final localized = CommunityChatRuntimeCopy.resolve(source, locale);
        expect(localized, isNotNull, reason: '$locale / $source');
        expect(localized!.trim(), isNotEmpty, reason: '$locale / $source');
        expect(localized, isNot(source), reason: '$locale / $source');
      }
    }
  });

  test('written language resolver uses text signals, not keyboard claims', () {
    expect(BilWrittenLanguageResolver.detectLocale('مرحبا'), 'ar');
    expect(
      BilWrittenLanguageResolver.detectLocale('سلام', fallbackLocaleTag: 'fa'),
      'fa',
    );
    expect(BilWrittenLanguageResolver.detectLocale('پیغام ہے'), 'ur');
    expect(BilWrittenLanguageResolver.detectLocale('Привіт'), 'uk');
    expect(BilWrittenLanguageResolver.detectLocale('bonjour'), isNull);
    expect(
      BilWrittenLanguageResolver.directionFor(
        'مرحبا بك',
        fallback: TextDirection.ltr,
      ),
      TextDirection.rtl,
    );
    expect(
      BilWrittenLanguageResolver.directionFor(
        'hello',
        fallback: TextDirection.rtl,
      ),
      TextDirection.ltr,
    );
  });
}
