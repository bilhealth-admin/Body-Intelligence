import '../../../data/database/app_database.dart';
import '../domain/unified_food.dart';
import 'database_food_adapter.dart';

class LegacyFoodAdapter extends BaseDatabaseFoodAdapter {
  const LegacyFoodAdapter();

  @override
  bool supports(Food food) => food.source.trim().toLowerCase() == 'legacy';

  @override
  FoodDataSource sourceFor(Food food) => FoodDataSource.legacy;
}
