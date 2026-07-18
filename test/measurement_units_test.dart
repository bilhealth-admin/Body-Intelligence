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

  test('display wheel steps closely preserve canonical physical steps', () {
    expect(UnitConverter.weightStep(MeasurementSystem.metric), 0.1);
    expect(
      UnitConverter.weightToKg(
        UnitConverter.weightStep(MeasurementSystem.imperial),
        MeasurementSystem.imperial,
      ),
      closeTo(0.1, 0.01),
    );
    expect(UnitConverter.heightStep(MeasurementSystem.metric), 1);
    expect(
      UnitConverter.heightToCm(
        UnitConverter.heightStep(MeasurementSystem.imperial),
        MeasurementSystem.imperial,
      ),
      closeTo(1, 0.02),
    );
  });
}
