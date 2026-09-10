import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_recovery_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
