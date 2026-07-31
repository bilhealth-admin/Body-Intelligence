enum MeasurementSystem { metric, imperial }

class UnitConverter {
  const UnitConverter._();

  static const double poundsPerKilogram = 2.2046226218;
  static const double centimetersPerInch = 2.54;

  static double weightFromKg(double kilograms, MeasurementSystem system) =>
      system == MeasurementSystem.metric
      ? kilograms
      : kilograms * poundsPerKilogram;

  static double weightToKg(double value, MeasurementSystem system) =>
      system == MeasurementSystem.metric ? value : value / poundsPerKilogram;

  static double heightFromCm(double centimeters, MeasurementSystem system) =>
      system == MeasurementSystem.metric
      ? centimeters
      : centimeters / centimetersPerInch;

  static double heightToCm(double value, MeasurementSystem system) =>
      system == MeasurementSystem.metric ? value : value * centimetersPerInch;

  static String weightUnit(MeasurementSystem system) =>
      system == MeasurementSystem.metric ? 'kg' : 'lb';

  static String heightUnit(MeasurementSystem system) =>
      system == MeasurementSystem.metric ? 'cm' : 'in';

  /// Display step approximating the canonical 0.1 kg step at one decimal.
  static double weightStep(MeasurementSystem system) =>
      system == MeasurementSystem.metric ? 0.1 : 0.2;

  /// Display step approximating the canonical 1 cm step at one decimal.
  static double heightStep(MeasurementSystem system) =>
      system == MeasurementSystem.metric ? 1 : 0.4;
}
