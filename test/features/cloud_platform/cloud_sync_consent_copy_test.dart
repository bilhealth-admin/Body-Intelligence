import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('benefit-led consent copy stays truthful and non-coercive', () {
    expect(CloudSyncConsentCopy.settingsTitle, 'Progress backup');
    expect(CloudSyncConsentCopy.title, 'Take your progress with you');
    expect(
      CloudSyncConsentCopy.title.toLowerCase().startsWith('cloud'),
      isFalse,
    );
    expect(
      CloudSyncConsentCopy.restoreBenefit,
      allOf(
        contains('profile'),
        contains('weight'),
        contains('water'),
        contains('reinstalling BIL'),
        contains('new phone'),
      ),
    );
    expect(
      CloudSyncConsentCopy.continuityBenefit,
      allOf(contains('records'), contains('signed-in devices')),
    );
    expect(
      CloudSyncConsentCopy.privacyBenefit,
      allOf(
        contains('Encrypted before upload'),
        contains('private to your account'),
        contains('Other users cannot see it'),
        contains('does not sell your data'),
      ),
    );
    expect(
      CloudSyncConsentCopy.localNutrition,
      'Meals stay fast and private on this device.',
    );
    expect(
      CloudSyncConsentCopy.choiceControl,
      'You can change this choice anytime in Privacy.',
    );
    expect(
      CloudSyncConsentCopy.deletionControl,
      allOf(contains('request deletion'), contains('saved cloud copy')),
    );
    expect(CloudSyncConsentCopy.primaryAction, contains('sync'));
    expect(CloudSyncConsentCopy.localAction, contains('on this device'));
    expect(
      CloudSyncConsentCopy.sources.join(' ').toLowerCase(),
      isNot(contains('all data')),
    );
  });

  test('all eleven consent messages resolve natively across 25 locales', () {
    final shipped = AppLocalizations.supportedLocales
        .map(BilLocalePolicy.canonicalTag)
        .toSet();
    expect(shipped, hasLength(25));
    expect(CloudSyncConsentCopy.supported, shipped);
    expect(CloudSyncConsentCopy.balanced, isTrue);

    for (final locale in shipped) {
      for (final source in CloudSyncConsentCopy.sources) {
        final translated = RuntimeCopy.resolve(source, locale);
        expect(
          translated,
          isNotNull,
          reason: 'Missing cloud consent copy for $locale: $source',
        );
        expect(translated!.trim(), isNotEmpty);
        expect(translated, isNot(contains('\uFFFD')));
        if (locale != 'en') {
          expect(
            translated,
            isNot(source),
            reason: 'Unreviewed English fallback for $locale: $source',
          );
        }
      }
    }
  });
}
