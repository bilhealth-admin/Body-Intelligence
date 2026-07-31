import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/dashboard/composition/dashboard_command_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardCommandCoordinator', () {
    test('remembers the action before storing its response', () async {
      final calls = <String>[];
      final coordinator = _coordinator(calls: calls);

      await coordinator.recordActionResponse(
        action: _action,
        response: 'notSuitable',
      );

      expect(calls, ['remember:hydration', 'respond:73:notSuitable']);
    });

    test('uses one injected clock for water and repeated meals', () async {
      final calls = <String>[];
      final at = DateTime(2026, 7, 31, 11, 15);
      final coordinator = _coordinator(calls: calls, now: at);
      final meal = _meal(at);
      final usual = UsualMealCandidate(source: meal, occurrences: 4);

      await coordinator.addWater(350);
      await coordinator.repeatUsualBreakfast(usual);
      await coordinator.repeatRecentBreakfast(meal);

      expect(calls, [
        'water:2026-07-31T11:15:00.000:350',
        'usual:4:2026-07-31T11:15:00.000',
        'historical:meal-1:2026-07-31T11:15:00.000',
      ]);
    });

    test('stops when remembering the action fails', () async {
      var responseCalled = false;
      final coordinator = DashboardCommandCoordinator(
        onRememberAction: (_) => Future<int>.error(StateError('write failed')),
        onRespondToAction: (_, _) async {
          responseCalled = true;
        },
        onAddWater: (_, _) async {},
        onRepeatUsualMeal: (_, _) async {},
        onRepeatHistoricalMeal: (_, _) async {},
        clock: DateTime.now,
      );

      await expectLater(
        coordinator.recordActionResponse(action: _action, response: 'done'),
        throwsStateError,
      );
      expect(responseCalled, isFalse);
    });
  });
}

const _action = BestAction(
  type: BestActionType.hydration,
  title: 'Hydrate',
  reason: 'Below target',
  evidence: ['water'],
);

DashboardCommandCoordinator _coordinator({
  required List<String> calls,
  DateTime? now,
}) {
  final clock = now ?? DateTime(2026, 7, 31);
  return DashboardCommandCoordinator(
    onRememberAction: (action) async {
      calls.add('remember:${action.type.name}');
      return 73;
    },
    onRespondToAction: (memoryId, response) async {
      calls.add('respond:$memoryId:$response');
    },
    onAddWater: (occurredAt, amountMl) async {
      calls.add('water:${occurredAt.toIso8601String()}:$amountMl');
    },
    onRepeatUsualMeal: (candidate, date) async {
      calls.add('usual:${candidate.occurrences}:${date.toIso8601String()}');
    },
    onRepeatHistoricalMeal: (meal, date) async {
      calls.add('historical:${meal.meal.uuid}:${date.toIso8601String()}');
    },
    clock: () => clock,
  );
}

MealWithItems _meal(DateTime at) => MealWithItems(
  meal: Meal(
    id: 1,
    uuid: 'meal-1',
    date: at,
    dayKey: '2026-07-31',
    name: 'Breakfast',
    type: 'breakfast',
    createdAt: at,
    updatedAt: at,
    revision: 1,
    syncStatus: 'synced',
  ),
  items: const [],
);
