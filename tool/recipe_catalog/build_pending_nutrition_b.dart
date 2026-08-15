import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

const ids = <String, int>{
  'rice': 168878,
  'black beans': 173735,
  'egg': 173424,
  'bell pepper': 170108,
  'onion': 790577,
  'tomato': 170457,
  'squash': 168475,
  'corn': 169999,
  'white beans': 175203,
  'potato': 170440,
  'pigeon peas': 170430,
  'snapper': 173698,
  'lime juice': 168156,
  'chicken breast': 171477,
  'corn tortilla': 175036,
  'avocado': 171705,
  'squash seeds': 170556,
  'red beans': 175194,
  'spinach': 168462,
  'feta cheese': 173420,
  'phyllo dough': 172791,
  'yogurt': 170903,
  'tahini': 170189,
  'kale': 168421,
  'pita bread': 174916,
  'ground beef': 171793,
  'cucumber': 168409,
  'bulgur': 170688,
};
const cols = <String, String>{
  'kcal': 'energy_kcal',
  'proteinG': 'protein_g',
  'carbsG': 'carbs_g',
  'fatG': 'fat_g',
  'fiberG': 'fiber_g',
  'sugarG': 'sugars_g',
  'sodiumMg': 'sodium_mg',
  'potassiumMg': 'potassium_mg',
};

void main() {
  final source =
      jsonDecode(
            File(
              'artifacts/meal_catalog/recipe_canonical_100.json',
            ).readAsStringSync(),
          )
          as Map;
  final pending = (source['records'] as List)
      .cast<Map>()
      .where((r) => (r['nutrition'] as Map)['status'] == 'pending')
      .toList();
  final selected = pending.sublist(pending.length - 17);
  final db = sqlite3.open(
    'assets/catalogs/bil_food_core.sqlite',
    mode: OpenMode.readOnly,
  );
  final output = <Map<String, Object?>>[];
  for (final recipe in selected) {
    final servings =
        (recipe['canonicalId'].toString().contains('sopa') ||
            recipe['canonicalId'].toString().contains('corbasi'))
        ? 6
        : 4;
    final totals = {for (final k in cols.keys) k: 0.0};
    final formulation = <Map<String, Object?>>[];
    final blocked = <String>[];
    for (final raw in recipe['ingredients'] as List) {
      final ing = (raw as Map).cast<String, Object?>();
      final item = ing['itemId'] as String;
      final id = ids[item];
      if (id == null) {
        blocked.add('$item:no_local_match');
        continue;
      }
      final rows = db.select('SELECT * FROM foods WHERE fdc_id=?', [id]);
      if (rows.length != 1) {
        blocked.add('$item:record_not_found');
        continue;
      }
      final row = rows.single;
      final missing = <String>[];
      for (final e in cols.entries) {
        final v = row[e.value];
        if (v is! num) {
          missing.add(e.key);
        } else {
          totals[e.key] =
              totals[e.key]! +
              v.toDouble() * (ing['grams'] as num).toDouble() / 100;
        }
      }
      if (missing.isNotEmpty) blocked.add('$item:missing_${missing.join('_')}');
      formulation.add({
        'itemId': item,
        'quantity': ing['grams'],
        'unit': 'g',
        'grams': ing['grams'],
        'recordId': 'usda:$id',
        'sourceRefs': [
          {
            'source': 'USDA FoodData Central via BIL local SQLite',
            'localRecordId': 'usda:$id',
            'fdcId': id,
            'description': row['description'],
          },
        ],
        'sourceDescription': row['description'],
      });
    }
    final ok = blocked.isEmpty;
    output.add({
      'canonicalId': recipe['canonicalId'],
      'contentFingerprint': recipe['contentFingerprint'],
      'image': recipe['image'],
      'status': ok ? 'calculated' : 'blocked',
      'blockedReasons': blocked,
      'formulationDisclosure':
          'Standardized BIL recipe specification; gram quantities are formulation inputs and were not inferred from imagery.',
      'servings': servings,
      'formulation': formulation,
      'timing': recipe['timing'],
      'method': recipe['method'],
      'nutritionPerServing': {
        for (final e in totals.entries)
          e.key: ok
              ? double.parse((e.value / servings).toStringAsFixed(2))
              : null,
      },
      'calculationRevision': 'bil-usda-local-pending-b-v1',
    });
  }
  db.close();
  final calculated = output.where((r) => r['status'] == 'calculated').length;
  File(
    'artifacts/meal_catalog/recipe_nutrition_pending_b.json',
  ).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'selection': 'last 17 nutrition.status=pending from recipe_canonical_100.json',
      'sourceDatabase': 'assets/catalogs/bil_food_core.sqlite',
      'formula': 'sum(per100g * grams / 100) / servings',
      'summary': {'records': 17, 'calculated': calculated, 'blocked': 17 - calculated},
      'records': output,
    })}\n',
  );
}
