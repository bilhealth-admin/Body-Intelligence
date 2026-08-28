import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/weight/services/weight_voice_input_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpokenWeightParser', () {
    test('accepts Arabic speech and Arabic-Indic digits', () {
      final result = SpokenWeightParser.parse(
        'وزني ٨٢٫٥ كيلو',
        fallbackSystem: MeasurementSystem.imperial,
      );

      expect(result, isNotNull);
      expect(result!.unit, SpokenWeightUnit.kilograms);
      expect(result.value, 82.5);
    });

    test('accepts English number words and pounds', () {
      final result = SpokenWeightParser.parse(
        'one hundred eighty pounds',
        fallbackSystem: MeasurementSystem.metric,
      );

      expect(result, isNotNull);
      expect(result!.unit, SpokenWeightUnit.pounds);
      expect(result.value, 180);
      expect(result.kilograms, closeTo(81.65, 0.01));
    });

    test('preserves a spoken English decimal instead of summing digits', () {
      final result = SpokenWeightParser.parse(
        'eighty two point five kilograms',
        fallbackSystem: MeasurementSystem.imperial,
      );

      expect(result, isNotNull);
      expect(result!.unit, SpokenWeightUnit.kilograms);
      expect(result.value, 82.5);
    });

    test('accepts Arabic number words and a spoken decimal', () {
      final result = SpokenWeightParser.parse(
        'اثنين وثمانين فاصلة خمسة كيلو',
        fallbackSystem: MeasurementSystem.imperial,
      );

      expect(result, isNotNull);
      expect(result!.unit, SpokenWeightUnit.kilograms);
      expect(result.value, 82.5);
    });

    test('uses the selected measurement system when unit is omitted', () {
      final result = SpokenWeightParser.parse(
        '72.4',
        fallbackSystem: MeasurementSystem.metric,
      );

      expect(result, isNotNull);
      expect(result!.unit, SpokenWeightUnit.kilograms);
      expect(result.value, 72.4);
    });

    test('rejects implausible values instead of changing the field', () {
      expect(
        SpokenWeightParser.parse(
          '900 kg',
          fallbackSystem: MeasurementSystem.metric,
        ),
        isNull,
      );
      expect(
        SpokenWeightParser.parse(
          'nothing useful',
          fallbackSystem: MeasurementSystem.metric,
        ),
        isNull,
      );
    });
  });
}
