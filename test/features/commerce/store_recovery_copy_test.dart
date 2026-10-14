import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_recovery_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';

void main() {
  test(
    'legal footer uses reviewed locale copy without AppLocalizations context',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = locale.toLanguageTag();
        for (final entry in const {
          'legal_terms': 'Terms of Use',
          'legal_privacy': 'Privacy Policy',
        }.entries) {
          final expected = RuntimeCopy.resolve(entry.value, tag);
          expect(expected, isNotNull, reason: '$tag:${entry.key}');
          expect(
            BilStoreCopy.text(tag, entry.key).replaceAll('’', "'"),
            expected!.replaceAll('’', "'"),
          );
          if (locale.languageCode != 'en') {
            expect(
              BilStoreCopy.text(tag, entry.key),
              isNot(entry.value),
              reason: tag,
            );
          }
        }
      }
    },
  );
  test(
    'inactive purchase is distinct from success in all supported locales',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = locale.toLanguageTag();
        final message = BilStoreCopy.text(tag, 'purchase_inactive');
        expect(message, isNot('purchase_inactive'));
        expect(message, isNot(BilStoreCopy.text(tag, 'purchase_verified')));
        if (locale.languageCode != 'en') {
          expect(
            message,
            isNot(BilStoreCopy.text('en', 'purchase_inactive')),
            reason: tag,
          );
        }
      }
    },
  );
  test('ownership conflict has distinct copy in all 25 locales', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = locale.toLanguageTag();
      const key = 'purchase_owned_by_another_account';
      final message = BilStoreCopy.text(tag, key);
      expect(message, isNotEmpty);
      expect(message, isNot(key));
      expect(message, isNot(BilStoreCopy.text(tag, 'restore_none')));
      if (locale.languageCode != 'en') {
        expect(message, isNot(BilStoreCopy.text('en', key)), reason: tag);
      }
    }
  });
  test(
    'all 25 locales distinguish store failure, unverified receipt and approval',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = locale.toLanguageTag();
        final messages = <String>{};
        for (final key in BilStoreRecoveryCopy.keys) {
          final message = BilStoreCopy.text(tag, key);
          expect(message, isNotEmpty);
          expect(message, isNot(key), reason: '$tag:$key');
          if (locale.languageCode != 'en') {
            expect(
              message,
              isNot(BilStoreCopy.text('en', key)),
              reason: '$tag:$key',
            );
          }
          messages.add(message);
        }
        expect(messages, hasLength(3));
      }
      expect(
        BilStoreCopy.text('ar', 'purchase_error'),
        isNot(contains('لم يتم منح')),
      );
      expect(
        BilStoreCopy.text('ar', 'purchase_verification_unavailable'),
        contains('قبل المحاولة'),
      );
    },
  );
}
