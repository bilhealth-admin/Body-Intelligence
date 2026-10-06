part of 'coach_meal_commit_boundary_test.dart';

void _coachMealOwnerAtomicityCases() {
  test(
    'different owner and permanently cancelled A B A scope cannot write',
    () async {
      final fixture = _MealFixture();
      addTearDown(fixture.database.close);
      final wrong = CoachMealOwnerScope(
        ownerId: 'owner-b',
        isCurrent: () => true,
      );
      await expectLater(
        fixture.meals.commitCoachMeal(
          command: fixture.macros('wrong-owner'),
          scope: wrong,
        ),
        _mealConflict(CoachMealConflictReason.ownerChanged),
      );
      final oldA = fixture.scope()..cancel();
      await expectLater(
        fixture.meals.commitCoachMeal(
          command: fixture.macros('returned-a'),
          scope: oldA,
        ),
        _mealConflict(CoachMealConflictReason.ownerChanged),
      );
      expect(
        await fixture.database.select(fixture.database.meals).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.preferences).get(),
        isEmpty,
      );
    },
  );

  test(
    'owner cancellation at every commit boundary either rolls back or reports a durable commit',
    () async {
      final probe = _MealFixture();
      var totalChecks = 0;
      await probe.meals.commitCoachMeal(
        command: probe.macros('probe'),
        scope: CoachMealOwnerScope(
          ownerId: 'owner-a',
          isCurrent: () {
            totalChecks++;
            return true;
          },
        ),
      );
      await probe.database.close();
      expect(totalChecks, greaterThan(20));
      var rolledBack = 0;
      var committed = 0;
      for (var stop = 1; stop <= totalChecks; stop++) {
        final fixture = _MealFixture();
        try {
          var checks = 0;
          final scope = CoachMealOwnerScope(
            ownerId: 'owner-a',
            isCurrent: () => ++checks < stop,
          );
          try {
            await fixture.meals.commitCoachMeal(
              command: fixture.macros('cancel-at-$stop'),
              scope: scope,
            );
            fail('The owner changed at check $stop');
          } on CoachMealConflict catch (error) {
            expect(error.reason, CoachMealConflictReason.ownerChanged);
            final items = await fixture.activeItems();
            final journals = await fixture.database
                .select(fixture.database.preferences)
                .get();
            if (error.committed) {
              committed++;
              expect(items, hasLength(1), reason: 'check $stop');
              expect(journals, hasLength(1));
            } else {
              rolledBack++;
              expect(items, isEmpty, reason: 'check $stop');
              expect(journals, isEmpty);
              expect(
                await fixture.database.select(fixture.database.foods).get(),
                isEmpty,
              );
              expect(
                await fixture.database.select(fixture.database.meals).get(),
                isEmpty,
              );
            }
          }
        } finally {
          await fixture.database.close();
        }
      }
      expect(rolledBack, greaterThan(0));
      expect(committed, greaterThan(0));
      expect(rolledBack + committed, totalChecks);
    },
  );
}
