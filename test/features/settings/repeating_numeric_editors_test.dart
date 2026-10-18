import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_goals_page.dart';
import 'package:body_intelligence_log/features/daily_check_in/daily_check_in_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../visual_closure/closure_surface_capture.dart';
import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  late AppDatabase db;
  late PreferencesRepository prefs;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    prefs = PreferencesRepository(db);
    await prefs.get('goals.workoutsPerWeek');
  });
  for (final fitness in [true, false]) {
    testWidgets(
      'actual ${fitness ? 'fitness goal' : 'daily weight'} repeats only draft and stops on cancel',
      (tester) async {
        debugPrint('Numeric editor database ready');
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            preferencesRepositoryProvider.overrideWithValue(prefs),
            todayWeightProvider.overrideWith((ref) => Stream.value(null)),
            latestWeightProvider.overrideWith((ref) => Stream.value(null)),
            weightHistoryProvider.overrideWith((ref) => Stream.value(const [])),
            measurementSystemProvider.overrideWith(
              (ref) => Stream.value(MeasurementSystem.metric),
            ),
            userProfileProvider.overrideWith(
              (ref) => Stream.value(
                UserProfileData(
                  id: 1,
                  uuid: 'synthetic-profile',
                  age: 30,
                  gender: 'male',
                  height: 175,
                  currentWeight: 80,
                  targetWeight: 76,
                  activityLevel: 'moderate',
                  exercises: false,
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                  revision: 1,
                  syncStatus: 'local',
                ),
              ),
            ),
          ],
        );
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: const Locale('ar'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: visualEvidenceTheme(
                  ThemeData(useMaterial3: true),
                  fontFamily: 'NotoArabicEvidence',
                ),
                builder: (context, child) => RepaintBoundary(
                  key: const Key('editor-capture'),
                  child: child!,
                ),
                home: fitness
                    ? const ReferenceGoalsPage()
                    : const DailyCheckInPage(),
              ),
            ),
          );
          for (var i = 0; i < 15; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }
          if (fitness) {
            final row = find.byKey(
              const Key('fitness-goal-goals.workoutsPerWeek'),
            );
            await tester.scrollUntilVisible(row, 400);
            await tester.pumpAndSettle();
            await tester.tap(row);
            await tester.pumpAndSettle();
          }
          final plus = find.byKey(
            Key(
              fitness
                  ? 'fitness-goal-increase'
                  : 'daily-check-in-weight-increase',
            ),
          );
          expect(plus.hitTestable(), findsOneWidget);
          final hold = await tester.startGesture(tester.getCenter(plus));
          await tester.pump(const Duration(milliseconds: 340));
          await tester.pump(const Duration(milliseconds: 150));
          await hold.up();
          await tester.pump();
          if (fitness) {
            expect(
              find.descendant(
                of: find.bySubtype<AlertDialog>(),
                matching: find.text('3'),
              ),
              findsOneWidget,
            );
          } else {
            expect(find.text('80.3'), findsOneWidget);
          }
          final saved = (await query(
            tester,
            prefs.get('goals.workoutsPerWeek'),
          ));
          expect(saved, isNull);
          expect(
            (await query(tester, db.select(db.weightEntries).get())),
            isEmpty,
          );
          await captureClosureSurface(
            tester,
            find.byKey(const Key('editor-capture')),
            fitness ? 'fitness-repeat-ar' : 'daily-weight-repeat-ar',
          );
          if (fitness) {
            await tester.tapAt(const Offset(4, 4));
            await tester.pumpAndSettle();
            expect(find.bySubtype<AlertDialog>(), findsNothing);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(
            (await query(tester, prefs.get('goals.workoutsPerWeek'))),
            isNull,
          );
          expect(tester.takeException(), isNull);
        } finally {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          container.dispose();
          await query(tester, db.close());
        }
      },
    );
  }
}

Future<T> query<T>(WidgetTester tester, Future<T> operation) async {
  var done = false;
  T? result;
  Object? error;
  operation.then(
    (value) {
      result = value;
      done = true;
    },
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  for (var i = 0; i < 100 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 5));
  }
  if (!done) {
    throw StateError('Timed out pumping a numeric editor database assertion');
  }
  if (error != null) throw error!;
  return result as T;
}
