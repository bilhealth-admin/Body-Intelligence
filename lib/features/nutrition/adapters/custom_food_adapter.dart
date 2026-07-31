import '../../../data/database/app_database.dart';
import '../domain/unified_food.dart';
import 'database_food_adapter.dart';

class CustomFoodAdapter extends BaseDatabaseFoodAdapter {
  const CustomFoodAdapter();

  @override
  bool supports(Food food) => food.isCustom;

  @override
  FoodDataSource sourceFor(Food food) => FoodDataSource.custom;
}
