import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/profile/profile_summary_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final samples = <({DateTime date, double weight})>[
    (date: DateTime.utc(2026, 8, 10), weight: 78),
    (date: DateTime.utc(2026, 8, 2), weight: 80),
    (date: DateTime.utc(2026, 7, 1), weight: 90),
  ];

  test('weight change is latest recorded minus earliest recorded', () {
    expect(profileWeightChangeKg(weights: samples), -12);

    final gained = <({DateTime date, double weight})>[
      (date: DateTime.utc(2026, 8, 2), weight: 80),
      (date: DateTime.utc(2026, 8, 10), weight: 82),
    ];
    expect(profileWeightChangeKg(weights: gained), 2);
  });

  test('calculation orders observations rather than trusting list order', () {
    final unordered = <({DateTime date, double weight})>[
      samples[1],
      samples[2],
      samples[0],
    ];
    expect(profileWeightChangeKg(weights: unordered), -12);
  });

  test('zero or one recorded observation is honestly unavailable', () {
    expect(profileWeightChangeKg(weights: const []), isNull);
    expect(profileWeightChangeKg(weights: [samples.first]), isNull);
  });

  test('signed display follows metric and imperial preferences', () {
    expect(
      formatProfileWeightChange(
        changeKg: -5,
        system: MeasurementSystem.metric,
        localeTag: 'en',
      ),
      '-5.0',
    );
    expect(
      formatProfileWeightChange(
        changeKg: 5,
        system: MeasurementSystem.imperial,
        localeTag: 'en',
      ),
      '+11.0',
    );
    expect(
      formatProfileWeightChange(
        changeKg: -0.001,
        system: MeasurementSystem.metric,
        localeTag: 'en',
      ),
      '0.0',
    );
  });

  test(
    'signed metric and imperial values format for every supported locale',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        expect(
          formatProfileWeightChange(
            changeKg: -5,
            system: MeasurementSystem.metric,
            localeTag: tag,
          ),
          startsWith('-'),
          reason: 'metric loss must remain signed for $tag',
        );
        expect(
          formatProfileWeightChange(
            changeKg: 5,
            system: MeasurementSystem.imperial,
            localeTag: tag,
          ),
          startsWith('+'),
          reason: 'imperial gain must remain signed for $tag',
        );
      }
    },
  );
}
