import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_chat_guard_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'private message limits and paging use authored actual resolution in all25 locales',
    () {
      expect(
        CommunityChatGuardCopy.values.keys.toSet(),
        BilLocalePolicy.productionTags.toSet(),
      );
      for (final source in CommunityChatGuardCopy.sources) {
        for (final tag in BilLocalePolicy.productionTags) {
          final value = CommunityChatGuardCopy.resolve(source, tag);
          expect(value, isNotNull);
          expect(value!.trim(), isNotEmpty);
          expect(
            communityTextForLanguage(
              tag,
              source,
              'Arabic fallback must not replace authored bank',
            ),
            value,
          );
          if (tag != 'en') expect(value, isNot(source));
        }
      }
    },
  );
}
