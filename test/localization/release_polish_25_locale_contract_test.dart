import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_release_actions.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_food_actions.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_daily_log_actions.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_fitness_watch.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_connected_health.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_release_polish.dart';
import 'package:body_intelligence_log/features/connected_health/partner_capabilities_copy.dart';
import 'package:body_intelligence_log/features/connected_health/partner_setup_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release-polish catalog resolves every source in all 25 locales', () {
    expect(ReleasePolishRuntimeCopy.supported, hasLength(25));
    expect(ReleasePolishRuntimeCopy.balanced, isTrue);
    expect(ReleasePolishRuntimeCopy.supported, RuntimeCopy.supported);

    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      expect(ReleasePolishRuntimeCopy.supported, contains(tag));
      for (final source in ReleasePolishRuntimeCopy.sources) {
        final value = ReleasePolishRuntimeCopy.resolve(source, tag);
        expect(value, isNotNull, reason: '$tag :: $source');
        expect(value!.trim(), isNotEmpty, reason: '$tag :: $source');
        expect(
          RuntimeCopy.resolve(source, tag),
          value,
          reason: '$tag :: $source',
        );
      }
      for (final source in const <String>[
        ReleasePolishRuntimeCopy.seePremiumPlans,
        ReleasePolishRuntimeCopy.sendMessage,
        ReleasePolishRuntimeCopy.accountChanged,
        ReleasePolishRuntimeCopy.reportMember,
        ReleasePolishRuntimeCopy.reportSentToModeration,
        ReleasePolishRuntimeCopy.presenterSuitability,
        ReleasePolishRuntimeCopy.lockedWorkoutSemantics,
      ]) {
        if (tag != 'en') {
          expect(
            ReleasePolishRuntimeCopy.resolve(source, tag),
            isNot(source),
            reason: 'English fallback leaked for $tag :: $source',
          );
        }
      }

      for (final source in const <String>[
        ReleasePolishRuntimeCopy.routineCount,
        ReleasePolishRuntimeCopy.workoutMinutes,
        ReleasePolishRuntimeCopy.workoutRepetitions,
        ReleasePolishRuntimeCopy.workoutSeconds,
        ReleasePolishRuntimeCopy.workoutRestSeconds,
      ]) {
        final rendered = ReleasePolishRuntimeCopy.format(
          source,
          locale,
          count: 7,
        );
        expect(rendered, contains('7'), reason: '$tag :: $source');
        expect(rendered, isNot(contains('{count}')), reason: '$tag :: $source');
      }
      final locked = ReleasePolishRuntimeCopy.format(
        ReleasePolishRuntimeCopy.lockedWorkoutSemantics,
        locale,
        level: 'PRO',
      );
      expect(locked, contains('PRO'), reason: tag);
      expect(locked, isNot(contains('{level}')), reason: tag);
    }
  });

  test('release-action catalog resolves all 13 sources in 25 locales', () {
    expect(ReleaseActionRuntimeCopy.supported, hasLength(25));
    expect(ReleaseActionRuntimeCopy.sources, hasLength(13));
    expect(ReleaseActionRuntimeCopy.balanced, isTrue);
    expect(ReleaseActionRuntimeCopy.supported, RuntimeCopy.supported);

    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final source in ReleaseActionRuntimeCopy.sources) {
        final value = ReleaseActionRuntimeCopy.resolve(source, tag);
        expect(value, isNotNull, reason: '$tag :: $source');
        expect(value!.trim(), isNotEmpty, reason: '$tag :: $source');
        expect(RuntimeCopy.resolve(source, tag), value);
        if (tag != 'en') {
          expect(
            value,
            isNot(source),
            reason: 'English fallback: $tag :: $source',
          );
        }
      }
    }
  });

  test('barcode safety copy resolves all sources in all 25 locales', () {
    expect(FoodActionRuntimeCopy.supported, hasLength(25));
    expect(FoodActionRuntimeCopy.sources, hasLength(4));
    expect(FoodActionRuntimeCopy.balanced, isTrue);
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final source in FoodActionRuntimeCopy.sources) {
        final value = FoodActionRuntimeCopy.resolve(source, tag);
        expect(value, isNotNull, reason: '$tag :: $source');
        expect(RuntimeCopy.resolve(source, tag), value);
        if (tag != 'en') {
          expect(
            value,
            isNot(source),
            reason: 'English fallback: $tag :: $source',
          );
        }
      }
    }
  });

  test('daily-log date actions resolve all sources in all 25 locales', () {
    expect(DailyLogActionRuntimeCopy.supported, hasLength(25));
    expect(DailyLogActionRuntimeCopy.sources, hasLength(3));
    expect(DailyLogActionRuntimeCopy.balanced, isTrue);
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final source in DailyLogActionRuntimeCopy.sources) {
        final value = DailyLogActionRuntimeCopy.resolve(source, tag);
        expect(value, isNotNull, reason: '$tag :: $source');
        expect(RuntimeCopy.resolve(source, tag), value);
        if (tag != 'en') {
          expect(
            value,
            isNot(source),
            reason: 'English fallback: $tag :: $source',
          );
        }
      }
    }
  });

  test('fitness watch labels resolve all sources in all 25 locales', () {
    expect(FitnessWatchRuntimeCopy.supported, hasLength(25));
    expect(FitnessWatchRuntimeCopy.sources, hasLength(6));
    expect(FitnessWatchRuntimeCopy.balanced, isTrue);
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final source in FitnessWatchRuntimeCopy.sources) {
        final value = FitnessWatchRuntimeCopy.resolve(source, tag);
        expect(value, isNotNull, reason: '$tag :: $source');
        expect(RuntimeCopy.resolve(source, tag), value);
        if (tag != 'en') {
          expect(
            value,
            isNot(source),
            reason: 'English fallback: $tag :: $source',
          );
        }
      }
    }
  });

  test(
    'connected-health templates resolve and replace parameters in 25 locales',
    () {
      expect(ConnectedHealthRuntimeCopy.supported, hasLength(25));
      expect(ConnectedHealthRuntimeCopy.balanced, isTrue);
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        for (final source in ConnectedHealthRuntimeCopy.sources) {
          final value = ConnectedHealthRuntimeCopy.resolve(source, tag);
          expect(value, isNotNull, reason: '$tag :: $source');
          expect(RuntimeCopy.resolve(source, tag), value);
        }
        for (final source in ConnectedHealthRuntimeCopy.sources) {
          final rendered = ConnectedHealthRuntimeCopy.formatForTag(
            tag,
            source,
            count: '7',
            code: 'CODE',
            time: '10:15',
            percent: '80',
          );
          expect(
            rendered,
            isNot(contains(RegExp(r'\{\w+\}'))),
            reason: '$tag :: $source',
          );
        }
      }
    },
  );

  test('partner capability surface is explicit across all 25 locales', () {
    expect(PartnerCapabilitiesCopy.supported, hasLength(25));
    expect(PartnerCapabilitiesCopy.balanced, isTrue);

    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      final copy = PartnerCapabilitiesCopy.forTag(tag);
      for (final source in PartnerCapabilitiesCopy.sources) {
        final value = copy.text(source);
        expect(value.trim(), isNotEmpty, reason: '$tag :: $source');
        if (tag != 'en') {
          expect(
            value,
            isNot(source),
            reason: 'English fallback: $tag :: $source',
          );
        }
      }
      expect(copy.text('health-connect'), 'Health Connect');
      expect(copy.text('healthkit'), 'Apple Health');
      expect(copy.text('garmin'), 'Garmin');
      expect(copy.text('fitbit'), 'Fitbit');
      expect(copy.text('samsung-health'), 'Samsung Health');
    }
  });

  test('official partner setup copy is explicit across all 25 locales', () {
    expect(PartnerSetupCopy.supported, hasLength(25));
    expect(PartnerSetupCopy.balanced, isTrue);
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      final copy = PartnerSetupCopy.forTag(tag);
      for (final source in PartnerSetupCopy.sources) {
        final value = copy.text(source);
        expect(value.trim(), isNotEmpty, reason: '$tag :: $source');
        if (tag != 'en') {
          expect(
            value,
            isNot(source),
            reason: 'English fallback: $tag :: $source',
          );
        }
      }
    }
  });

  test('user-visible call sites delegate to complete reviewed catalogs', () {
    final premium = File(
      'lib/features/commerce/presentation/premium_logging_intro_page.dart',
    ).readAsStringSync();
    final communityChat = File(
      'lib/features/community/presentation/community_chat_page.dart',
    ).readAsStringSync();
    final connections = File(
      'lib/features/community/presentation/community_connections_copy.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/profile/premium_profile_actions.dart',
    ).readAsStringSync();
    final presenter = File(
      'lib/features/wellness/presentation/bil_workout_routine_presenters.dart',
    ).readAsStringSync();
    final state = File(
      'lib/features/wellness/presentation/bil_workout_routines_states.dart',
    ).readAsStringSync();
    final details = File(
      'lib/features/wellness/presentation/bil_workout_routine_details.dart',
    ).readAsStringSync();
    final partner = File(
      'lib/features/connected_health/partner_capabilities_page.dart',
    ).readAsStringSync();
    final dailySummary = File(
      'lib/features/daily_log/presentation/daily_log_summary_widgets.dart',
    ).readAsStringSync();
    final quickMacro = File(
      'lib/features/daily_log/presentation/quick_macro_entry_dialog.dart',
    ).readAsStringSync();
    final barcode = File(
      'lib/features/nutrition/presentation/food_barcode_scanner_page.dart',
    ).readAsStringSync();
    final fitnessDevices = File(
      'lib/features/connected_health/connected_health_components.dart',
    ).readAsStringSync();
    final foodActions = File(
      'lib/features/nutrition/presentation/food_page_actions.dart',
    ).readAsStringSync();
    final dailyNavigation = File(
      'lib/features/daily_log/daily_log_navigation_actions.dart',
    ).readAsStringSync();
    final watch = File(
      'lib/features/connected_health/widgets/live_health_watch.dart',
    ).readAsStringSync();
    final healthCard = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();

    expect(premium, contains('ReleasePolishRuntimeCopy.resolve(key, code)'));
    expect(premium, contains('ReleaseActionRuntimeCopy.resolve(key, code)'));
    for (final source in const <String>[
      ReleaseActionRuntimeCopy.noThanks,
      ReleaseActionRuntimeCopy.logFoodInSeconds,
      ReleaseActionRuntimeCopy.fastestBilTools,
      ReleaseActionRuntimeCopy.scanBarcode,
      ReleaseActionRuntimeCopy.identifyPackagedProducts,
      ReleaseActionRuntimeCopy.logWithVoice,
      ReleaseActionRuntimeCopy.describeMeal,
      ReleaseActionRuntimeCopy.analyzeMealPhoto,
      ReleaseActionRuntimeCopy.photoStartingPoint,
    ]) {
      expect(premium, contains(source));
    }
    expect(quickMacro, contains(ReleaseActionRuntimeCopy.nonNegativeNumber));
    expect(quickMacro, contains(ReleaseActionRuntimeCopy.saveEntryFailed));
    expect(barcode, contains(ReleaseActionRuntimeCopy.lookUp));
    expect(
      fitnessDevices,
      contains(ReleaseActionRuntimeCopy.compatibleFitnessMeasurements),
    );
    for (final source in FoodActionRuntimeCopy.sources) {
      expect(foodActions, contains(source));
    }
    for (final source in DailyLogActionRuntimeCopy.sources) {
      expect(dailyNavigation, contains(source));
    }
    for (final source in FitnessWatchRuntimeCopy.sources) {
      expect('$watch\n$healthCard', contains(source));
    }
    expect(communityChat, contains('RuntimeCopy.resolve(en, localeTag)'));
    expect(communityChat, contains("'Send message'"));
    expect(connections, contains("t('Report member')"));
    expect(connections, contains("t('Report sent to moderation.')"));
    expect(profile, contains(ReleasePolishRuntimeCopy.accountChanged));
    expect(
      presenter,
      contains('ReleasePolishRuntimeCopy.presenterSuitability'),
    );
    expect(state, contains('ReleasePolishRuntimeCopy.routineCount'));
    expect(state, contains('ReleasePolishRuntimeCopy.workoutRestSeconds'));
    expect(
      details,
      contains('ReleasePolishRuntimeCopy.lockedWorkoutSemantics'),
    );
    expect(partner, contains('PartnerCapabilitiesCopy.of(context).text(key)'));
    expect(partner, isNot(contains('const _copy =')));
    for (final nutrient in const ['Sodium', 'Potassium', 'Magnesium']) {
      expect(dailySummary, contains("context.strings.text('$nutrient')"));
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        expect(
          RuntimeCopy.resolve(nutrient, tag),
          isNotNull,
          reason: '$tag :: $nutrient',
        );
      }
    }
  });
}
