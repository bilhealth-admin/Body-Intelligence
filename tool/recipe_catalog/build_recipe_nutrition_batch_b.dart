import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const revision = 'bil-usda-local-recipe-formulation-v1';

const formulations = <String, List<(int, double, String)>>{
  'overnight-oats-figs': [
    (168872, 40, 'raw oat bran'),
    (170903, 150, 'plain low-fat yogurt'),
    (173021, 100, 'raw figs'),
  ],
  'spinach-omelet': [
    (173424, 100, 'cooked whole egg'),
    (168462, 50, 'raw spinach'),
    (170457, 100, 'raw red ripe tomato'),
    (170931, .5, 'black pepper'),
  ],
  'shrimp-rice-bowl': [
    (171971, 120, 'cooked shrimp'),
    (168878, 150, 'cooked long-grain white rice'),
    (169975, 60, 'raw green cabbage'),
    (168568, 50, 'raw carrot'),
    (168411, 50, 'prepared frozen edamame'),
  ],
  'tofu-stir-fry': [
    (172448, 150, 'firm tofu'),
    (168510, 100, 'cooked broccoli'),
    (170427, 80, 'raw green sweet pepper'),
    (170010, 80, 'raw edible-podded peas'),
  ],
  'bean-corn-salad': [
    (173735, 130, 'cooked black beans without salt'),
    (169999, 100, 'cooked sweet corn without salt'),
    (170457, 100, 'raw red ripe tomato'),
    (790577, 30, 'raw red onion'),
    (168156, 15, 'raw lime juice'),
  ],
  'chicken-sweet-potato': [
    (171477, 150, 'roasted chicken breast meat only'),
    (168484, 200, 'boiled sweet potato'),
    (169141, 100, 'cooked green beans without salt'),
    (170416, 5, 'fresh parsley as specified herb'),
  ],
  'mediterranean-chicken-bowl': [
    (171477, 150, 'roasted chicken breast meat only'),
    (168917, 150, 'cooked quinoa as specified grain'),
    (170457, 100, 'raw red ripe tomato'),
    (168409, 100, 'raw cucumber'),
    (170903, 50, 'plain low-fat yogurt'),
  ],
  'roasted-quinoa-bowl': [
    (168917, 150, 'cooked quinoa'),
    (169292, 100, 'cooked zucchini as seasonal vegetable'),
    (170427, 100, 'raw green sweet pepper as seasonal vegetable'),
    (167747, 15, 'raw lemon juice'),
    (170416, 5, 'fresh parsley as specified herb'),
  ],
  'salmon-avocado-bowl': [
    (172001, 150, 'cooked pink salmon'),
    (168917, 150, 'cooked quinoa as specified grain'),
    (171705, 75, 'raw avocado'),
    (168409, 100, 'raw cucumber'),
  ],
};

const times = <String, (int, int)>{
  'overnight-oats-figs': (5, 0),
  'spinach-omelet': (5, 7),
  'shrimp-rice-bowl': (10, 15),
  'tofu-stir-fry': (10, 15),
  'bean-corn-salad': (12, 0),
  'chicken-sweet-potato': (10, 30),
  'mediterranean-chicken-bowl': (10, 20),
  'roasted-quinoa-bowl': (10, 25),
  'salmon-avocado-bowl': (10, 15),
};

const methods = <String, List<String>>{
  'overnight-oats-figs': [
    'Combine 40 g oat bran and 150 g yogurt.',
    'Refrigerate overnight; top with 100 g figs before serving.',
  ],
  'spinach-omelet': [
    'Wilt 50 g spinach and 100 g tomato in a non-stick pan.',
    'Add 100 g beaten cooked-equivalent egg, season with 0.5 g pepper, and cook gently until set.',
  ],
  'shrimp-rice-bowl': [
    'Prepare the measured cabbage, carrot, and edamame.',
    'Cook shrimp until opaque and food-safe.',
    'Serve with 150 g cooked rice and the measured vegetables.',
  ],
  'tofu-stir-fry': [
    'Cut tofu and measured vegetables evenly.',
    'Brown tofu in a non-stick pan.',
    'Stir-fry vegetables until tender-crisp and combine.',
  ],
  'bean-corn-salad': [
    'Drain and rinse beans and corn.',
    'Combine all measured ingredients and dress with 15 g lime juice.',
  ],
  'chicken-sweet-potato': [
    'Cut sweet potato and arrange with chicken and green beans.',
    'Roast until chicken is food-safe and sweet potato tender.',
    'Finish with 5 g parsley.',
  ],
  'mediterranean-chicken-bowl': [
    'Cook chicken until food-safe and prepare the measured vegetables.',
    'Build the bowl with cooked quinoa, vegetables, yogurt, and chicken.',
  ],
  'roasted-quinoa-bowl': [
    'Roast the measured zucchini and pepper until tender.',
    'Serve over cooked quinoa with lemon juice and parsley.',
  ],
  'salmon-avocado-bowl': [
    'Cook salmon until food-safe.',
    'Arrange with cooked quinoa, avocado, and cucumber.',
  ],
};

void main() {
  final db = sqlite3.open(
    'assets/catalogs/bil_food_core.sqlite',
    mode: OpenMode.readOnly,
  );
  final seeds =
      (jsonDecode(
                File(
                  'artifacts/meal_catalog/existing_recipe_canonical_seeds.json',
                ).readAsStringSync(),
              )['records']
              as List)
          .cast<Map<String, Object?>>();
  final byId = {for (final seed in seeds) seed['canonicalId'] as String: seed};
  final output = <Map<String, Object?>>[];
  const nutrientColumns = {
    'kcal': 'energy_kcal',
    'proteinG': 'protein_g',
    'carbohydrateG': 'carbs_g',
    'fatG': 'fat_g',
    'fiberG': 'fiber_g',
    'sugarG': 'sugars_g',
    'sodiumMg': 'sodium_mg',
    'potassiumMg': 'potassium_mg',
  };
  for (final entry in formulations.entries) {
    final blocked = <String>[];
    final totals = {for (final key in nutrientColumns.keys) key: 0.0};
    final evidence = <Map<String, Object?>>[];
    for (final item in entry.value) {
      final rows = db.select('SELECT * FROM foods WHERE fdc_id=?', [item.$1]);
      if (rows.length != 1) {
        blocked.add('${item.$3}:missing_fdc_${item.$1}');
        continue;
      }
      final row = rows.single;
      final missing = <String>[];
      for (final nutrient in nutrientColumns.entries) {
        final raw = row[nutrient.value];
        if (raw is! num) {
          missing.add(nutrient.key);
        } else {
          totals[nutrient.key] =
              totals[nutrient.key]! + raw.toDouble() * item.$2 / 100;
        }
      }
      if (missing.isNotEmpty) {
        blocked.add('${item.$3}:missing_${missing.join('_')}');
      }
      evidence.add({
        'ingredient': item.$3,
        'grams': item.$2,
        'fdcId': item.$1,
        'recordId': 'usda:${item.$1}',
        'sourceRefs': [
          {
            'source': 'USDA FoodData Central via BIL local SQLite',
            'localRecordId': 'usda:${item.$1}',
            'fdcId': item.$1,
            'description': row['description'],
          },
        ],
        'description': row['description'],
        'sourceDataset': row['source_dataset'],
        'basis': 'per 100 g',
        'requiredNutrientsComplete': missing.isEmpty,
      });
    }
    final timing = times[entry.key]!;
    final complete = blocked.isEmpty;
    final perServing = <String, double?>{
      for (final nutrient in totals.entries)
        nutrient.key: complete
            ? double.parse(nutrient.value.toStringAsFixed(2))
            : null,
    };
    output.add({
      'canonicalId': entry.key,
      'contentFingerprint': byId[entry.key]!['contentFingerprint'],
      'seedContentFingerprint': byId[entry.key]!['contentFingerprint'],
      'image': byId[entry.key]!['image'],
      'formulationStatus': complete ? 'calculated' : 'blocked',
      'formulationDisclosure':
          'Standardized BIL recipe formulation; quantities were assigned for reproducible calculation and were not inferred from the image.',
      'servings': 1,
      'timing': {
        'prepMinutes': timing.$1,
        'cookMinutes': timing.$2,
        'totalMinutes': timing.$1 + timing.$2,
      },
      'ingredients': evidence,
      'method': [
        for (var i = 0; i < methods[entry.key]!.length; i++)
          {'order': i + 1, 'instruction': methods[entry.key]![i]},
      ],
      'nutrition': {
        'status': complete ? 'calculated' : 'pending',
        'calculationRevision': revision,
        'sourceRefs': [for (final row in evidence) 'USDA-FDC:${row['fdcId']}'],
        'recordIds': [for (final row in evidence) row['recordId']],
        'perServing': perServing,
      },
      'nutritionPerServing': {
        'kcal': perServing['kcal'],
        'proteinG': perServing['proteinG'],
        'carbsG': perServing['carbohydrateG'],
        'fatG': perServing['fatG'],
        'fiberG': perServing['fiberG'],
        'sugarG': perServing['sugarG'],
        'sodiumMg': perServing['sodiumMg'],
        'potassiumMg': perServing['potassiumMg'],
      },
      'blockedReasons': blocked,
    });
  }
  db.close();
  final complete = output
      .where((r) => r['formulationStatus'] == 'calculated')
      .length;
  final artifact = {
    'schemaVersion': 1,
    'batch': 'B',
    'scope': 'existing recipes 10-18',
    'calculationRevision': revision,
    'sourceDatabase': 'assets/catalogs/bil_food_core.sqlite',
    'summary': {
      'records': output.length,
      'calculated': complete,
      'blocked': output.length - complete,
    },
    'records': output,
  };
  File(
    'artifacts/meal_catalog/existing_recipe_nutrition_batch_b.json',
  ).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(artifact)}\n',
  );
}
