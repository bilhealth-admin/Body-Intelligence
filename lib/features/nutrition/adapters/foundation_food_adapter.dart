import '../../../data/database/app_database.dart';
import '../domain/unified_food.dart';
import 'database_food_adapter.dart';

class FoundationFoodAdapter extends BaseDatabaseFoodAdapter {
  const FoundationFoodAdapter();

  @override
  bool supports(Food food) {
    if (food.isCustom) return false;
    final source = food.source.trim().toLowerCase();
    return source == 'local' || source == 'starter' || source == 'foundation';
  }

  @override
  FoodDataSource sourceFor(Food food) => FoodDataSource.foundation;
}
