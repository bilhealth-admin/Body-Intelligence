// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Read-only inventory of the exact ingredient-to-food mappings shipped in BIL.
void main(List<String> args) {
  final db = sqlite3.open(
    'assets/catalogs/bil_food_core.sqlite',
    mode: OpenMode.readOnly,
  );
  try {
    if (args.isNotEmpty) {
      for (final term in args) {
        print('TERM: $term');
        for (final row in db.select(
          '''SELECT fdc_id, description, energy_kcal, protein_g,
                    carbs_g, fat_g, fiber_g, sugars_g, sodium_mg, potassium_mg
             FROM foods WHERE lower(description) LIKE ? AND energy_kcal IS NOT NULL
             ORDER BY length(description), description LIMIT 18''',
          ['%${term.toLowerCase()}%'],
        )) {
          print(jsonEncode(row));
        }
      }
      return;
    }
    final groups = <String, ({Set<String> recipes, Set<String> sources})>{};
    final files = Directory(
      'assets/catalogs/recipes/v1/shards',
    ).listSync().whereType<File>().where((file) => file.path.endsWith('.json'));
    for (final file in files) {
      final shard = jsonDecode(file.readAsStringSync()) as Map;
      for (final record in shard['records'] as List) {
        for (final ingredient in record['ingredients'] as List) {
          final name = ingredient['itemId'] as String;
          final group = groups.putIfAbsent(
            name,
            () => (recipes: {}, sources: {}),
          );
          group.recipes.add(record['canonicalId'] as String);
          final id = ingredient['recordId'] as String?;
          final rows = id == null
              ? const <Row>[]
              : db.select('SELECT description FROM foods WHERE fdc_id = ?', [
                  int.parse(id.split(':').last),
                ]);
          group.sources.add(
            '$id | ${rows.isEmpty ? 'MISSING' : rows.single['description']}',
          );
        }
      }
    }
    final names = groups.keys.toList()..sort();
    print('Distinct ingredients: ${names.length}');
    for (final name in names) {
      final group = groups[name]!;
      print(
        '$name | ${group.recipes.length} recipes | ${group.sources.join('; ')}',
      );
    }
  } finally {
    db.close();
  }
}
