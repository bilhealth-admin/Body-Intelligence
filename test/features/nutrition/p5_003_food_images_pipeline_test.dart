import 'package:body_intelligence_log/features/nutrition/domain/food_image.dart';
import 'package:body_intelligence_log/features/nutrition/integrations/open_food_facts/open_food_facts_mapper.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenFoodFacts mapper preserves explainable image references', () {
    const mapper = OpenFoodFactsMapper();
    final food = mapper.mapProduct(
      barcode: '4006381333931',
      product: <String, Object?>{
        'product_name': 'Test food',
        'image_front_url': 'https://images.example/front.jpg',
        'image_url': 'https://images.example/front.jpg',
        'image_nutrition_url': 'https://images.example/nutrition.jpg',
        'image_ingredients_url': 'https://images.example/ingredients.jpg',
        'nutriments': <String, Object?>{'energy-kcal_100g': 100},
      },
    )!;

    expect(food.images, hasLength(3));
    expect(food.images.first.role, FoodImageRole.front);
    expect(food.images.first.isPrimary, isTrue);
    expect(food.images.first.source, FoodImageSource.openFoodFacts);
    expect(food.images.first.attribution, 'OpenFoodFacts');
  });

  test('pipeline is deterministic, deduplicated, localized, and safe', () {
    const pipeline = FoodImagePipeline();
    final result = pipeline.resolve(<FoodImageReference>[
      FoodImageReference(
        id: 'unsafe',
        uri: Uri.parse('javascript:alert(1)'),
        role: FoodImageRole.front,
        source: FoodImageSource.remote,
      ),
      FoodImageReference(
        id: 'english-front',
        uri: Uri.parse('https://images.example/front-en.jpg#fragment'),
        role: FoodImageRole.front,
        source: FoodImageSource.remote,
        locale: 'en-US',
        width: 1000,
        height: 1000,
      ),
      FoodImageReference(
        id: 'arabic-front',
        uri: Uri.parse('https://images.example/front-ar.jpg'),
        role: FoodImageRole.front,
        source: FoodImageSource.remote,
        locale: 'ar-EG',
        width: 800,
        height: 800,
      ),
      FoodImageReference(
        id: 'arabic-front-duplicate',
        uri: Uri.parse('https://images.example/front-ar.jpg'),
        role: FoodImageRole.other,
        source: FoodImageSource.remote,
      ),
      FoodImageReference(
        id: 'nutrition',
        uri: Uri.parse('http://images.example/nutrition.jpg'),
        role: FoodImageRole.nutrition,
        source: FoodImageSource.remote,
        isPrimary: true,
      ),
    ], preferredLocale: 'ar');

    expect(result.images, hasLength(3));
    expect(result.primary?.id, 'nutrition');
    expect(result.images[1].id, 'arabic-front');
    expect(result.rejectedIds, <String>['unsafe']);
    expect(result.images[1].uri.fragment, isEmpty);
  });

  test('non-positive dimensions and invalid limits are rejected safely', () {
    const pipeline = FoodImagePipeline();
    final empty = pipeline.resolve(<FoodImageReference>[
      FoodImageReference(
        id: 'invalid-size',
        uri: Uri.parse('https://images.example/image.jpg'),
        role: FoodImageRole.other,
        source: FoodImageSource.remote,
        width: 0,
      ),
    ], limit: 1);
    expect(empty.images, isEmpty);
    expect(empty.rejectedIds, <String>['invalid-size']);

    final disabled = pipeline.resolve(const <FoodImageReference>[], limit: 0);
    expect(disabled.images, isEmpty);
    expect(disabled.primary, isNull);
  });
}
