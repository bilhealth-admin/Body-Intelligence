import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_connected_health.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const guidanceSources = <String>{
    ConnectedHealthRuntimeCopy.approvedCategoriesOnly,
    ConnectedHealthRuntimeCopy.connectionDataDetails,
    ConnectedHealthRuntimeCopy.supportedFitnessDevices,
    ConnectedHealthRuntimeCopy.appleWatchViaHealth,
  };

  test('connected-health guidance has reviewed copy in every locale', () {
    expect(AppLocalizations.supportedLocales, hasLength(25));
    expect(ConnectedHealthRuntimeCopy.supported, hasLength(25));
    expect(ConnectedHealthRuntimeCopy.balanced, isTrue);
    expect(
      ConnectedHealthRuntimeCopy.sources.toSet(),
      containsAll(guidanceSources),
    );

    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final source in guidanceSources) {
        final localized = ConnectedHealthRuntimeCopy.resolve(source, tag);
        expect(localized, isNotNull, reason: '$tag :: $source');
        expect(localized!.trim(), isNotEmpty, reason: '$tag :: $source');
        expect(RuntimeCopy.resolve(source, tag), localized);
        if (tag != 'en') {
          expect(
            localized,
            isNot(source),
            reason: 'English fallback: $tag :: $source',
          );
        }
      }
    }
  });

  test('connected-health helper routes guidance through reviewed copy', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      if (tag == 'ar') continue;
      for (final source in guidanceSources) {
        expect(
          connectedHealthTextForLanguage(tag, source, 'ترجمة عربية'),
          ConnectedHealthRuntimeCopy.resolve(source, tag),
          reason: '$tag :: $source',
        );
      }
    }
  });
}
