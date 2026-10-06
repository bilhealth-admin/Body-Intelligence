import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../nutrition/domain/unified_food.dart' show FoodNutrient;

export '../../../nutrition/domain/unified_food.dart' show FoodNutrient;

part 'coach_food_snapshot.dart';
part 'coach_food_quantity.dart';
part 'coach_food_nutrition.dart';
part 'coach_food_resolution.dart';
part 'coach_food_replacement.dart';

/// Local, side-effect-free Food V2 contracts. No provider or database is opened.
///
/// A validated proposal is not a commit receipt. Adapters must still perform
/// admission, owner checks, an atomic repository write and committed readback.
final class CoachFoodContractError implements Exception {
  const CoachFoodContractError(this.code, {this.field});

  final String code;
  final String? field;

  @override
  String toString() =>
      'CoachFoodContractError($code${field == null ? '' : ', $field'})';
}

Never _foodReject(String code, [String? field]) =>
    throw CoachFoodContractError(code, field: field);

String _foodText(Object? value, String field, int maximum) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.runes.length > maximum ||
      value.runes.any((rune) => rune < 32 || rune == 127)) {
    _foodReject('invalid_text', field);
  }
  return value.trim();
}

double _foodNumber(
  Object? value,
  String field, {
  double minimum = 0,
  double maximum = double.maxFinite,
}) {
  if (value is! num) _foodReject('invalid_number', field);
  final number = value.toDouble();
  if (!number.isFinite || number < minimum || number > maximum) {
    _foodReject('invalid_number', field);
  }
  return number == 0 ? 0 : number;
}

Map<String, Object?> _foodObject(
  Object? value,
  Set<String> allowed,
  Set<String> required,
  String field,
) {
  if (value is! Map ||
      value.keys.any((key) => key is! String || !allowed.contains(key))) {
    _foodReject('unknown_field', field);
  }
  if (!required.every(value.containsKey)) {
    _foodReject('missing_field', field);
  }
  return Map<String, Object?>.from(value);
}

int _foodRevision(Object? value) {
  if (value is! int || value < 1 || value > 9007199254740991) {
    _foodReject('invalid_revision');
  }
  return value;
}

String _foodDigest(Object? value) {
  Object? canonical(Object? current) {
    if (current is Map<String, Object?>) {
      final keys = current.keys.toList()..sort();
      return {for (final key in keys) key: canonical(current[key])};
    }
    if (current is List) return current.map(canonical).toList(growable: false);
    return current;
  }

  return sha256.convert(utf8.encode(jsonEncode(canonical(value)))).toString();
}
