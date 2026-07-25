import 'app_database.dart';
import '../repositories/food_repository.dart';

class SeedData {
  static Future<void> seedStarterCatalog(FoodRepository repository) async {
    final foods = await repository.getFoods();
    final byName = {for (final food in foods) food.name: food};

    await _ensureStarter(
      repository,
      byName['Chicken Breast'],
      name: 'Chicken Breast',
      arabicName: 'صدر دجاج',
      category: 'Protein',
      calories: 165,
      protein: 31,
      carbs: 0,
      fats: 3.6,
      fiber: 0,
      sugar: 0,
      sodium: 74,
      potassium: 256,
      calcium: 15,
      magnesium: 29,
      source: 'USDA FoodData Central 171477',
    );
    await _ensureStarter(
      repository,
      byName['Greek Yogurt'],
      name: 'Greek Yogurt',
      arabicName: 'زبادي يوناني',
      category: 'Dairy',
      calories: 59,
      protein: 10,
      carbs: 3.6,
      fats: 0.4,
      fiber: 0,
      sugar: 3.27,
      sodium: 36,
      potassium: 141,
      calcium: 111,
      magnesium: 11,
      source: 'USDA FoodData Central 2705424',
    );
    await _ensureStarter(
      repository,
      byName['Oats'],
      name: 'Oats',
      arabicName: 'شوفان',
      category: 'Grains',
      calories: 389,
      protein: 16.9,
      carbs: 66.3,
      fats: 6.9,
      fiber: 10.1,
      sugar: 0.99,
      sodium: 6,
      potassium: 362,
      calcium: 52,
      magnesium: 138,
      source: 'USDA FoodData Central 173904',
    );
    await _ensureStarter(
      repository,
      byName['Apple'],
      name: 'Apple',
      arabicName: 'تفاحة',
      category: 'Fruit',
      calories: 52,
      protein: 0.3,
      carbs: 14,
      fats: 0.2,
      fiber: 2.4,
      sugar: 10.4,
      sodium: 1,
      potassium: 107,
      calcium: 6,
      magnesium: 5,
      source: 'USDA FoodData Central SR Legacy',
    );
  }

  static Future<void> _ensureStarter(
    FoodRepository repository,
    Food? existing, {
    required String name,
    required String arabicName,
    required String category,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    required double fiber,
    required double sugar,
    required double sodium,
    required double potassium,
    required double calcium,
    required double magnesium,
    required String source,
  }) async {
    if (existing == null) {
      await repository.addFood(
        name: name,
        arabicName: arabicName,
        category: category,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fats: fats,
        fiber: fiber,
        sugar: sugar,
        sodium: sodium,
        potassium: potassium,
        calcium: calcium,
        magnesium: magnesium,
        source: source,
        verified: true,
        isCustom: false,
      );
      return;
    }
    await repository.repairBundledFoodNutrients(
      id: existing.id,
      source: source,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      potassium: potassium,
      calcium: calcium,
      magnesium: magnesium,
    );
  }
}
