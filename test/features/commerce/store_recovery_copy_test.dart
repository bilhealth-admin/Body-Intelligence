import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_recovery_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';

void main() {
  test(
    'cancelled and unconfirmed restores stay distinct in all 25 locales',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = locale.toLanguageTag();
        final outcomes = {
          for (final key in const ['restore_cancelled', 'restore_unconfirmed'])
            key: BilStoreCopy.text(tag, key),
        };
        expect(outcomes.values.toSet(), hasLength(2), reason: tag);
        for (final outcome in outcomes.entries) {
          expect(outcome.value, isNotEmpty, reason: '$tag:${outcome.key}');
          expect(outcome.value, isNot(outcome.key), reason: tag);
          if (locale.languageCode != 'en') {
            expect(
              outcome.value,
              isNot(BilStoreCopy.text('en', outcome.key)),
              reason: '$tag:${outcome.key}',
            );
          }
          for (final key in const [
            'restore_verified',
            'restore_checked',
            'restore_none',
            'restore_failed',
            'restore_checking',
          ]) {
            expect(
              outcome.value,
              isNot(BilStoreCopy.text(tag, key)),
              reason: '$tag:${outcome.key} must not claim $key',
            );
          }
        }
      }
    },
  );

  test('settled verification is localized in every supported locale', () {
    const key = 'purchase_verified';
    final english = BilStoreCopy.text('en', key);
    expect(english, 'Purchase verified.');
    expect(BilStoreCopy.text('ar', key), 'تم التحقق من الشراء.');
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = locale.toLanguageTag();
      final settled = BilStoreCopy.text(tag, key);
      expect(settled, isNotEmpty, reason: tag);
      expect(settled, isNot(key), reason: tag);
      expect(
        settled,
        isNot(BilStoreCopy.text(tag, 'purchase_in_progress')),
        reason: tag,
      );
      expect(
        settled,
        isNot(BilStoreCopy.text(tag, 'purchase_inactive')),
        reason: tag,
      );
      if (locale.languageCode != 'en') {
        expect(settled, isNot(english), reason: tag);
      }
      final oldPendingCopy = RuntimeCopy.resolve(
        'Purchase verified. Your access is updating.',
        tag,
      );
      if (oldPendingCopy != null) {
        expect(settled, isNot(oldPendingCopy), reason: tag);
      }
    }
  });

  test('settled verification resolves normalized regional locale tags', () {
    for (final tags in const [
      ['pt-BR', 'PT_br'],
      ['pt-PT', 'PT_pt'],
      ['zh-Hans', 'ZH_hans'],
      ['zh-Hant', 'ZH_hant'],
    ]) {
      expect(
        BilStoreCopy.text(tags[1], 'purchase_verified'),
        BilStoreCopy.text(tags[0], 'purchase_verified'),
        reason: tags.join(' / '),
      );
    }
  });

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
