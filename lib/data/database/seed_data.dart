import '../repositories/food_repository.dart';

class SeedData {
  static Future<void> seedStarterCatalog(FoodRepository repository) async {
    final existingFoods = await repository.getFoods();
    if (existingFoods.isNotEmpty) {
      return;
    }

    await repository.addFood(
      name: 'Chicken Breast',
      arabicName: 'صدر دجاج',
      category: 'Protein',
      calories: 165,
      protein: 31,
      carbs: 0,
      fats: 3.6,
      isCustom: false,
    );

    await repository.addFood(
      name: 'Greek Yogurt',
      arabicName: 'زبادي يوناني',
      category: 'Dairy',
      calories: 59,
      protein: 10,
      carbs: 3.6,
      fats: 0.4,
      isCustom: false,
    );

    await repository.addFood(
      name: 'Oats',
      arabicName: 'شوفان',
      category: 'Grains',
      calories: 389,
      protein: 16.9,
      carbs: 66.3,
      fats: 6.9,
      isCustom: false,
    );

    await repository.addFood(
      name: 'Apple',
      arabicName: 'تفاحة',
      category: 'Fruit',
      calories: 52,
      protein: 0.3,
      carbs: 14,
      fats: 0.2,
      isCustom: false,
    );
  }
}
