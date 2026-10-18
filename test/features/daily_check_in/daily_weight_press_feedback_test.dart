import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/daily_check_in/daily_check_in_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:body_intelligence_log/shared/widgets/bil_glass_press_feedback.dart';
import 'package:body_intelligence_log/shared/widgets/wheel_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'daily weight plus and minus do not borrow a distant arrow bubble',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayWeightProvider.overrideWith((ref) => Stream.value(null)),
            latestWeightProvider.overrideWith((ref) => Stream.value(null)),
            userProfileProvider.overrideWith(
              (ref) => Stream.value(
                UserProfileData(
                  id: 1,
                  uuid: 'daily-weight-feedback-profile',
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
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => Stack(
              fit: StackFit.expand,
              children: [
                child!,
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: () {},
                    icon: const BilGlassPressFeedback(
                      child: Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ),
              ],
            ),
            home: const DailyCheckInPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final plus = find.byKey(const Key('daily-check-in-weight-increase'));
      final plusPress = await tester.startGesture(tester.getCenter(plus));
      await tester.pump();
      expect(find.byKey(const Key('bil-sdk-arrow-glass-bubble')), findsNothing);
      expect(find.byKey(const Key('bil-glass-press-bubble')), findsNothing);
      await plusPress.up();
      await tester.pumpAndSettle();
      expect(find.text('82.1'), findsOneWidget);

      final minus = find.byKey(const Key('daily-check-in-weight-decrease'));
      final minusPress = await tester.startGesture(tester.getCenter(minus));
      await tester.pump();
      expect(find.byKey(const Key('bil-sdk-arrow-glass-bubble')), findsNothing);
      expect(find.byKey(const Key('bil-glass-press-bubble')), findsNothing);
      await minusPress.up();
      await tester.pumpAndSettle();
      expect(find.text('82.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'weight history scale plus and minus keep their own interaction feedback',
    (tester) async {
      var weight = 82.0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              child!,
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () {},
                  icon: const BilGlassPressFeedback(
                    child: Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
            ],
          ),
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => SmartWeightScaleField(
                  value: weight,
                  minimum: 20,
                  maximum: 300,
                  step: .1,
                  decimalPlaces: 1,
                  unit: 'kg',
                  label: 'Weight',
                  onChanged: (next) => setState(() => weight = next),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final (key, expected) in const [
        ('smart-weight-scale-increase', 82.1),
        ('smart-weight-scale-decrease', 82.0),
      ]) {
        final control = find.byKey(Key(key));
        final press = await tester.startGesture(tester.getCenter(control));
        await tester.pump();
        expect(
          find.byKey(const Key('bil-sdk-arrow-glass-bubble')),
          findsNothing,
        );
        expect(find.byKey(const Key('bil-glass-press-bubble')), findsNothing);
        await press.up();
        await tester.pumpAndSettle();
        expect(weight, closeTo(expected, .0001));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
