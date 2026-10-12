import 'dart:convert';
import '../../features/intelligence_center/domain/food_v2/coach_food_v2.dart';

/// An immutable declared volume/count basis. It never claims a gram weight.
final class UnitFoodEvidence {
  UnitFoodEvidence({
    required this.identity,
    required this.name,
    required this.source,
    required this.ownerKey,
    required this.basisQuantity,
    required this.unit,
    required this.quantity,
    required this.nutrients,
  }) {
    if (identity.isEmpty ||
        identity.length > 240 ||
        name.isEmpty ||
        name.length > 500 ||
        source.isEmpty ||
        source.length > 4096 ||
        ownerKey.isEmpty ||
        ownerKey.length > 200 ||
        !const {
          'ml',
          'l',
          'serving',
          'piece',
          'cup',
          'tbsp',
          'tsp',
          'entry',
        }.contains(unit) ||
        !basisQuantity.isFinite ||
        basisQuantity <= 0 ||
        basisQuantity > 100000 ||
        !quantity.isFinite ||
        quantity <= 0 ||
        quantity > 1000000) {
      throw const FormatException('Invalid declared unit food evidence.');
    }
    for (final n in FoodNutrient.values) {
      if (value(n) case final amount? when !amount.isFinite || amount > 1e9) {
        throw const FormatException('Invalid declared unit total.');
      }
    }
  }
  static const schema = 'bil.food.unit.v1', sourcePrefix = 'unit_food_v1:';
  final String identity, name, source, ownerKey, unit;
  final double basisQuantity, quantity;
  final CoachFoodNutrients nutrients;
  String get sourceLabel => '$sourcePrefix$source';
  double? value(FoodNutrient n) =>
      nutrients[n] == null ? null : nutrients[n]! * quantity / basisQuantity;
  UnitFoodEvidence withQuantity(double amount) => UnitFoodEvidence(
    identity: identity,
    name: name,
    source: source,
    ownerKey: ownerKey,
    basisQuantity: basisQuantity,
    unit: unit,
    quantity: amount,
    nutrients: nutrients,
  );
  String encodeForStorage() => jsonEncode({
    'schema': schema,
    'identity': identity,
    'name': name,
    'source': source,
    'ownerKey': ownerKey,
    'unit': unit,
    'basisQuantity': basisQuantity,
    'quantity': quantity,
    'nutrients': nutrients.toJson(),
  });
  factory UnitFoodEvidence.decode(String raw) {
    if (utf8.encode(raw).length > 65536) {
      throw const FormatException('Food evidence too large.');
    }
    final data = jsonDecode(raw);
    const keys = {
      'schema',
      'identity',
      'name',
      'source',
      'ownerKey',
      'unit',
      'basisQuantity',
      'quantity',
      'nutrients',
    };
    if (data is! Map ||
        data.length != keys.length ||
        !keys.every(data.containsKey) ||
        data['schema'] != schema ||
        data['identity'] is! String ||
        data['name'] is! String ||
        data['source'] is! String ||
        data['ownerKey'] is! String ||
        data['unit'] is! String ||
        data['basisQuantity'] is! num ||
        data['quantity'] is! num) {
      throw const FormatException('Invalid food unit snapshot.');
    }
    return UnitFoodEvidence(
      identity: data['identity'],
      name: data['name'],
      source: data['source'],
      ownerKey: data['ownerKey'],
      unit: data['unit'],
      basisQuantity: (data['basisQuantity'] as num).toDouble(),
      quantity: (data['quantity'] as num).toDouble(),
      nutrients: CoachFoodNutrients.fromJson(data['nutrients']),
    );
  }
}
