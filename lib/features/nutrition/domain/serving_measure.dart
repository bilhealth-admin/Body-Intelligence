import 'unified_food.dart';

/// A user-facing serving definition resolved to a stable gram amount.
class ServingMeasure {
  final String id;
  final String label;
  final double amount;
  final String unit;
  final double grams;

  const ServingMeasure({
    required this.id,
    required this.label,
    required this.amount,
    required this.unit,
    required this.grams,
  });

  FoodServing get serving =>
      FoodServing(amount: amount, unit: unit, grams: grams);
}
