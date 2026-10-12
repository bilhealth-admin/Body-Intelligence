import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/first_meal_celebration.dart';
import 'package:body_intelligence_log/shared/widgets/bil_experience_presentation.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> mountBurst(
  WidgetTester tester, {
  bool reduced = false,
}) async {
  late BuildContext target;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          target = context;
          return const Scaffold(body: Text('Synthetic food save target'));
        },
      ),
    ),
  );
  await tester.pump();
  return target;
}

void main() {
  testWidgets(
    'inactive first-food event stays ready until a foreground offer',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      addTearDown(() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      final prefs = PreferencesRepository(db);
      await prefs.set(firstMealCelebrationPreferenceKey, 'ready');
      final target = await mountBurst(tester, reduced: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(await FirstMealCelebration.showIfPending(target, prefs), isFalse);
      await tester.pump();
      expect(await prefs.get(firstMealCelebrationPreferenceKey), 'ready');
      expect(BilExperiencePresentation.occupied.value, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(await FirstMealCelebration.showIfPending(target, prefs), isTrue);
      await tester.pump();
      for (
        var i = 0;
        i < 20 && await prefs.get(firstMealCelebrationPreferenceKey) != 'done';
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(await prefs.get(firstMealCelebrationPreferenceKey), 'done');
      expect(await db.select(db.meals).get(), isEmpty);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'disposed first-food overlay releases the lease reduced=$reduced',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
        final prefs = PreferencesRepository(db);
        await prefs.set(firstMealCelebrationPreferenceKey, 'ready');
        final target = await mountBurst(tester, reduced: reduced);
        expect(await FirstMealCelebration.showIfPending(target, prefs), isTrue);
        await tester.pump();
        for (
          var i = 0;
          i < 20 &&
              await prefs.get(firstMealCelebrationPreferenceKey) != 'done';
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(await prefs.get(firstMealCelebrationPreferenceKey), 'done');
        expect(BilExperiencePresentation.occupied.value, isTrue);
        // Dispose before either approved animation duration has elapsed.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(BilExperiencePresentation.occupied.value, isFalse);
        final release = BilExperiencePresentation.tryClaim();
        expect(release, isNotNull);
        release!();
        expect(await prefs.get(firstMealCelebrationPreferenceKey), 'done');
        expect(await db.select(db.meals).get(), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
