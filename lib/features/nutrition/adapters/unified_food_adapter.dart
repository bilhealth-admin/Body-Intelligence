import '../../../data/database/app_database.dart';
import '../domain/unified_food.dart';
import 'branded_food_adapter.dart';
import 'custom_food_adapter.dart';
import 'database_food_adapter.dart';
import 'foundation_food_adapter.dart';
import 'legacy_food_adapter.dart';

class UnifiedFoodAdapter {
  final List<DatabaseFoodAdapter> _adapters;
  final BaseDatabaseFoodAdapter _fallback;

  const UnifiedFoodAdapter({
    this._adapters = const <DatabaseFoodAdapter>[
      CustomFoodAdapter(),
      BrandedFoodAdapter(),
      LegacyFoodAdapter(),
      FoundationFoodAdapter(),
    ],
  }) : _fallback = const _UnknownFoodAdapter();

  UnifiedFood adapt(Food food) {
    for (final adapter in _adapters) {
      if (adapter.supports(food)) return adapter.adapt(food);
    }
    return _fallback.adapt(food);
  }

  List<UnifiedFood> adaptAll(Iterable<Food> foods) =>
      foods.map(adapt).toList(growable: false);
}

class _UnknownFoodAdapter extends BaseDatabaseFoodAdapter {
  const _UnknownFoodAdapter();

  @override
  bool supports(Food food) => true;

  @override
  FoodDataSource sourceFor(Food food) => FoodDataSource.unknown;
}
