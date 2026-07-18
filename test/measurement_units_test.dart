import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'weight conversions round-trip without changing canonical kilograms',
    () {
      const kilograms = 73.4;
      final pounds = UnitConverter.weightFromKg(
        kilograms,
        MeasurementSystem.imperial,
      );

      expect(pounds, closeTo(161.819, 0.001));
      expect(
        UnitConverter.weightToKg(pounds, MeasurementSystem.imperial),
        closeTo(kilograms, 0.000001),
      );
    },
  );

  test(
    'height conversions round-trip without changing canonical centimeters',
    () {
      const centimeters = 172.5;
      final inches = UnitConverter.heightFromCm(
        centimeters,
        MeasurementSystem.imperial,
      );

      expect(inches, closeTo(67.913, 0.001));
      expect(
        UnitConverter.heightToCm(inches, MeasurementSystem.imperial),
        closeTo(centimeters, 0.000001),
      );
    },
  );
}
