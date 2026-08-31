import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/daily_check_in/daily_check_in_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:body_intelligence_log/features/weight/services/weight_voice_input_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('daily check-in exposes reviewed voice weight entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayWeightProvider.overrideWith((ref) => Stream.value(null)),
          latestWeightProvider.overrideWith((ref) => Stream.value(null)),
          userProfileProvider.overrideWith(
            (ref) => Stream.value(
              UserProfileData(
                id: 1,
                uuid: 'profile-id',
                age: 30,
                gender: 'male',
                height: 175,
                currentWeight: 82,
                targetWeight: 76,
                activityLevel: 'moderate',
                exercises: false,
                createdAt: DateTime(2026, 8, 21),
                updatedAt: DateTime(2026, 8, 21),
                revision: 1,
                syncStatus: 'local',
              ),
            ),
          ),
          measurementSystemProvider.overrideWith(
            (ref) => Stream.value(MeasurementSystem.metric),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DailyCheckInPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('daily-check-in-weight-voice')),
      findsOneWidget,
    );
    expect(find.byTooltip('Voice input'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('measurement-system failure renders recovery without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayWeightProvider.overrideWith((ref) => Stream.value(null)),
          latestWeightProvider.overrideWith((ref) => Stream.value(null)),
          userProfileProvider.overrideWith(
            (ref) => Stream.value(
              UserProfileData(
                id: 1,
                uuid: 'profile-id',
                age: 30,
                gender: 'male',
                height: 175,
                currentWeight: 89.7,
                targetWeight: 80.7,
                activityLevel: 'moderate',
                exercises: false,
                createdAt: DateTime(2026, 8, 21),
                updatedAt: DateTime(2026, 8, 21),
                revision: 1,
                syncStatus: 'local',
              ),
            ),
          ),
          measurementSystemProvider.overrideWith(
            (ref) => Stream.error(StateError('private preference detail')),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DailyCheckInPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weight data could not be loaded.'), findsOneWidget);
    expect(find.textContaining('private preference detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reviewed speech populates numeric daily weight, never raw words',
    (tester) async {
      SpokenWeightCandidate? captureResult = SpokenWeightParser.parse(
        'اثنين وثمانين فاصلة خمسة كيلو',
        fallbackSystem: MeasurementSystem.metric,
        localeTag: 'ar',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayWeightProvider.overrideWith((ref) => Stream.value(null)),
            latestWeightProvider.overrideWith((ref) => Stream.value(null)),
            userProfileProvider.overrideWith(
              (ref) => Stream.value(
                UserProfileData(
                  id: 1,
                  uuid: 'profile-id',
                  age: 30,
                  gender: 'male',
                  height: 175,
                  currentWeight: 80,
                  targetWeight: 76,
                  activityLevel: 'moderate',
                  exercises: false,
                  createdAt: DateTime(2026, 8, 21),
                  updatedAt: DateTime(2026, 8, 21),
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
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: DailyCheckInPage(voiceCapture: (_, _) async => captureResult),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('daily-check-in-weight-voice')));
      await tester.pumpAndSettle();

      expect(find.text('82.5'), findsOneWidget);
      expect(find.textContaining('اثنين وثمانين'), findsNothing);

      captureResult = null;
      await tester.tap(find.byKey(const Key('daily-check-in-weight-voice')));
      await tester.pumpAndSettle();
      expect(find.text('82.5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
