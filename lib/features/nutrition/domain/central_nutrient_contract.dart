final class AvailableNutrient {
  const AvailableNutrient.known(this.value) : isAvailable = true;
  const AvailableNutrient.unknown() : value = null, isAvailable = false;

  final double? value;
  final bool isAvailable;
}

/// Canonical definition. Unknown is deliberately distinct from measured zero.
AvailableNutrient netCarbohydrates({
  required AvailableNutrient totalCarbohydrates,
  required AvailableNutrient fiber,
}) {
  if (!totalCarbohydrates.isAvailable || !fiber.isAvailable) {
    return const AvailableNutrient.unknown();
  }
  return AvailableNutrient.known(
    (totalCarbohydrates.value! - fiber.value!).clamp(0, double.infinity),
  );
}
