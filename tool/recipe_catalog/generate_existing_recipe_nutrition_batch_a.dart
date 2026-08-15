import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

const _seedPath =
    'artifacts/meal_catalog/existing_recipe_canonical_seeds.json';
const _catalogPath = 'assets/catalogs/bil_food_core.sqlite';
const _outputPath =
    'artifacts/meal_catalog/existing_recipe_nutrition_batch_a.json';
const _expectedSeedSha256 =
    '279ca4d3e95b37d2d98ae7fa73f6f148f4545fe04d415d8b3943705afc96b02a';

const _formulations = <String, ({int servings, int prep, int cook, List<({String item, double grams, int fdc})> items})>{
  'lentil-soup': (servings: 4, prep: 10, cook: 25, items: [(item: 'red-lentils', grams: 200, fdc: 172420), (item: 'onion', grams: 150, fdc: 790646), (item: 'carrot', grams: 120, fdc: 168568), (item: 'cumin', grams: 4, fdc: 170923), (item: 'water-or-unsalted-stock', grams: 800, fdc: 173647)]),
  'yogurt-oats': (servings: 1, prep: 5, cook: 0, items: [(item: 'plain-yogurt', grams: 200, fdc: 171284), (item: 'rolled-oats', grams: 50, fdc: 173904), (item: 'fresh-fruit', grams: 120, fdc: 1105897), (item: 'optional-nuts-or-seeds', grams: 15, fdc: 170158)]),
  'chickpea-salad': (servings: 2, prep: 15, cook: 0, items: [(item: 'cooked-chickpeas', grams: 300, fdc: 173757), (item: 'tomato', grams: 150, fdc: 170457), (item: 'cucumber', grams: 150, fdc: 168409), (item: 'parsley', grams: 20, fdc: 170416), (item: 'lemon-juice', grams: 30, fdc: 167747)]),
  'shakshuka': (servings: 2, prep: 10, cook: 15, items: [(item: 'eggs', grams: 200, fdc: 173424), (item: 'tomatoes', grams: 400, fdc: 170457), (item: 'onion', grams: 120, fdc: 790577), (item: 'parsley', grams: 15, fdc: 170416), (item: 'cumin', grams: 3, fdc: 170923)]),
  'grilled-fish-vegetables': (servings: 2, prep: 10, cook: 20, items: [(item: 'fish-fillet', grams: 300, fdc: 171956), (item: 'zucchini', grams: 250, fdc: 169291), (item: 'tomatoes', grams: 200, fdc: 170457), (item: 'lemon', grams: 60, fdc: 167746), (item: 'herbs', grams: 10, fdc: 170416)]),
  'chicken-shawarma-bowl': (servings: 2, prep: 15, cook: 20, items: [(item: 'chicken-breast', grams: 300, fdc: 171477), (item: 'cooked-grain', grams: 300, fdc: 169704), (item: 'cabbage', grams: 150, fdc: 169975), (item: 'tomato', grams: 150, fdc: 170457), (item: 'yogurt', grams: 100, fdc: 171284)]),
  'vegetable-lentil-stew': (servings: 4, prep: 10, cook: 30, items: [(item: 'brown-lentils', grams: 200, fdc: 172420), (item: 'carrot', grams: 150, fdc: 168568), (item: 'tomato', grams: 300, fdc: 170457), (item: 'spinach', grams: 150, fdc: 168462), (item: 'cumin', grams: 4, fdc: 170923)]),
  'hummus-falafel-plate': (servings: 2, prep: 15, cook: 20, items: [(item: 'chickpeas', grams: 300, fdc: 173757), (item: 'tahini', grams: 60, fdc: 170189), (item: 'cucumber', grams: 150, fdc: 168409), (item: 'tomato', grams: 150, fdc: 170457), (item: 'flatbread', grams: 120, fdc: 174915)]),
  'quinoa-tabbouleh': (servings: 4, prep: 20, cook: 0, items: [(item: 'cooked-quinoa', grams: 500, fdc: 168917), (item: 'parsley', grams: 80, fdc: 170416), (item: 'tomato', grams: 250, fdc: 170457), (item: 'cucumber', grams: 200, fdc: 168409), (item: 'lemon', grams: 100, fdc: 167746)]),
};

void main() {
  final seedBytes = File(_seedPath).readAsBytesSync();
  final seedHash = sha256.convert(seedBytes).toString();
  if (seedHash != _expectedSeedSha256) {
    throw StateError('Seed bytes changed; refusing to generate batch A.');
  }
  final seed = jsonDecode(utf8.decode(seedBytes)) as Map<String, dynamic>;
  final records = (seed['records'] as List<dynamic>).take(9).cast<Map<String, dynamic>>();
  final database = sqlite3.open(_catalogPath, mode: OpenMode.readOnly);
  try {
    final outputRecords = records.map((record) {
      final id = record['canonicalId'] as String;
      final formulation = _formulations[id]!;
      final ingredients = formulation.items
          .map((item) => _ingredient(database, item.item, item.grams, item.fdc))
          .toList(growable: false);
      final totals = <String, double>{for (final key in _nutrientColumns.keys) key: 0};
      for (final ingredient in ingredients) {
        final grams = ingredient['grams'] as double;
        final per100 = ingredient['nutrientsPer100g'] as Map<String, dynamic>;
        for (final key in totals.keys) {
          totals[key] = totals[key]! + (per100[key] as num).toDouble() * grams / 100;
        }
      }
      final perServing = {for (final entry in totals.entries) entry.key: _round(entry.value / formulation.servings)};
      return <String, dynamic>{
        'canonicalId': id,
        'seedContentFingerprint': record['contentFingerprint'],
        'status': 'verified-calculation',
        'formulationProvenance': 'BIL standardized recipe formulation v1; editorial quantities, not inferred from an image or the incomplete legacy seed',
        'servings': formulation.servings,
        'formulation': ingredients,
        'nutritionPerServing': perServing,
        'calculationRevision': 'bil-usda-local-formulation-v1',
        'timing': {'prepMinutes': formulation.prep, 'cookMinutes': formulation.cook, 'totalMinutes': formulation.prep + formulation.cook},
        'method': ((record['localizations'] as Map<String, dynamic>)['en'] as Map<String, dynamic>)['steps'],
      };
    }).toList(growable: false);

    final output = <String, dynamic>{
      'schemaVersion': 1,
      'batch': 'A',
      'recordCount': outputRecords.length,
      'sourceSeed': {
        'path': _seedPath,
        'sha256': seedHash,
        'selection': 'records[0..8]',
      },
      'nutritionSource': {
        'type': 'bil-usda-sqlite-local-only',
        'path': _catalogPath,
        'sha256': sha256.convert(File(_catalogPath).readAsBytesSync()).toString(),
      },
      'calculationPolicy': {
        'formula':
            'sum(nutrient_per_100g * ingredient_grams / 100) / servings',
        'requiresCompleteGramFormulation': true,
        'requiresPositiveServingCount': true,
        'missingValuePolicy': 'blocked-not-zero',
        'candidateSourceRefsAreNotCalculableMatches': true,
      },
      'records': outputRecords,
    };
    File(_outputPath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(output)}\n',
    );
  } finally {
    database.close();
  }
}

const _nutrientColumns = <String, String>{'kcal': 'energy_kcal', 'proteinG': 'protein_g', 'carbsG': 'carbs_g', 'fatG': 'fat_g', 'fiberG': 'fiber_g', 'sugarG': 'sugars_g', 'sodiumMg': 'sodium_mg', 'potassiumMg': 'potassium_mg'};

Map<String, dynamic> _ingredient(Database database, String itemId, double grams, int id) {
  final rows = database.select('SELECT * FROM foods WHERE fdc_id = ?', [id]);
  if (rows.length != 1) throw StateError('Local USDA record $id missing/duplicated.');
  final row = rows.single;
  final nutrients = <String, double>{};
  for (final entry in _nutrientColumns.entries) {
    final value = row[entry.value];
    if (value is! num) throw StateError('USDA $id lacks required ${entry.value}.');
    nutrients[entry.key] = value.toDouble();
  }
  return {
    'itemId': itemId,
    'quantity': grams,
    'unit': 'g',
    'grams': grams,
    'sourceMatchStatus': 'selected',
    'sourceRefs': [{'source': 'USDA FoodData Central via BIL local SQLite', 'localRecordId': 'usda:$id', 'fdcId': id, 'description': row['description']}],
    'nutrientsPer100g': nutrients,
  };
}

double _round(double value) => (value * 100).round() / 100;
