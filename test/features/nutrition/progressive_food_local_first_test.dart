import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/nutrition/services/trusted_food_network_search_resolver.dart';

class _BlockedCloud extends TrustedFoodNetworkSearchResolver {
  final called = Completer<void>();
  final result = Completer<List<UnifiedFood>>();
  @override
  Future<List<UnifiedFood>> search(String query, {int limit = 10}) {
    if (!called.isCompleted) called.complete();
    return result.future;
  }
}

void main() {
  late AppDatabase db;
  late FoodRepository foods;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    foods = FoodRepository(db);
  });
  tearDown(() => db.close());
  Future<void> seed() => foods
      .addFood(
        name: 'Chicken',
        arabicName: 'دجاج',
        category: 'protein',
        calories: 165,
        protein: 31,
        carbs: 0,
        fats: 3.6,
        servingSize: 100,
        servingUnit: 'g',
      )
      .then((_) {});
  test(
    'Arabic local results render while the cloud is still blocked',
    () async {
      await seed();
      final cloud = _BlockedCloud();
      final authority = FoodRuntimeSearchAuthority(
        foods,
        catalogResolver: () async => null,
        networkSearchResolver: cloud,
      );
      final local = Completer<List<Food>>();
      final finished = Completer<void>();
      final subscription = authority
          .searchProgressively('دجاج', remoteDebounce: Duration.zero)
          .listen(
            (rows) {
              if (!local.isCompleted) local.complete(rows);
            },
            onDone: finished.complete,
            onError: finished.completeError,
          );
      final rows = await local.future;
      expect(rows.single.arabicName, 'دجاج');
      expect(cloud.result.isCompleted, isFalse);
      await cloud.called.future;
      expect(finished.isCompleted, isFalse);
      cloud.result.complete(const []);
      await finished.future;
      await subscription.cancel();
    },
  );
  test('take-first cancellation does not start a cloud request', () async {
    await seed();
    final cloud = _BlockedCloud();
    final authority = FoodRuntimeSearchAuthority(
      foods,
      catalogResolver: () async => null,
      networkSearchResolver: cloud,
    );
    final rows = await authority.searchProgressively('دجاج').first;
    expect(rows, isNotEmpty);
    expect(cloud.called.isCompleted, isFalse);
  });
  test('zero limit returns no rows without invalid clamp bounds', () async {
    final authority = FoodRuntimeSearchAuthority(
      foods,
      catalogResolver: () async => null,
    );
    expect(
      await authority.searchProgressively('دجاج', limit: 0).first,
      isEmpty,
    );
  });
}
