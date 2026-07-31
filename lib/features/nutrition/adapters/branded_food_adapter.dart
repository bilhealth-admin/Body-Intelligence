import '../../../data/database/app_database.dart';
import '../domain/unified_food.dart';
import 'database_food_adapter.dart';

class BrandedFoodAdapter extends BaseDatabaseFoodAdapter {
  const BrandedFoodAdapter();

  @override
  bool supports(Food food) {
    final source = food.source.trim().toLowerCase();
    return source == 'branded' || source == 'brand';
  }

  @override
  FoodDataSource sourceFor(Food food) => FoodDataSource.branded;
}
