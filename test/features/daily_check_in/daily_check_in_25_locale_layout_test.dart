import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/daily_check_in/daily_check_in_locale_copy.dart';
import 'package:body_intelligence_log/features/daily_check_in/daily_check_in_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily check-in critical copy is reviewed for all 25 locales', () {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final key in dailyCheckInRequiredKeys) {
        final value = dailyCheckInTextForTag(locale.toLanguageTag(), key);
        expect(
          value.trim(),
          isNotEmpty,
          reason: '${locale.toLanguageTag()}: $key',
        );
        if (locale.languageCode != 'en') {
          expect(value, isNot(key), reason: '${locale.toLanguageTag()}: $key');
        }
      }
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'daily check-in fits ${locale.toLanguageTag()} at 390x844 and 160%',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todayWeightProvider.overrideWith((ref) => Stream.value(null)),
              latestWeightProvider.overrideWith((ref) => Stream.value(null)),
              userProfileProvider.overrideWith(
                (ref) => Stream.value(
                  UserProfileData(
                    id: 1,
                    uuid: 'layout-profile',
                    age: 30,
                    gender: 'male',
                    height: 175,
                    currentWeight: 89.7,
                    targetWeight: 78,
                    activityLevel: 'moderate',
                    exercises: true,
                    createdAt: DateTime(2026, 8, 23),
                    updatedAt: DateTime(2026, 8, 23),
                    revision: 1,
                    syncStatus: 'local',
                  ),
                ),
              ),
              measurementSystemProvider.overrideWith(
                (ref) => Stream.value(MeasurementSystem.metric),
              ),
            ],
            child: MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(390, 844),
                  textScaler: TextScaler.linear(1.6),
                ),
                child: const DailyCheckInPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('daily-check-in-hero')), findsOneWidget);
        expect(
          find.text(
            dailyCheckInTextForTag(
              locale.toLanguageTag(),
              'How much do you weigh today?',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('After bathroom'), findsNothing);
        expect(find.text('Private progress photo'), findsNothing);
        final differentTime = find.byKey(
          const Key('daily-check-in-context-differentConditions'),
        );
        await tester.scrollUntilVisible(
          differentTime,
          200,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 12,
        );
        await tester.pumpAndSettle();
        expect(differentTime, findsOneWidget);
        expect(tester.getBottomRight(differentTime).dy, lessThanOrEqualTo(844));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
