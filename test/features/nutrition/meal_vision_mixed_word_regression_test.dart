import 'dart:convert';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

const _bad = 'الوزن تقديري بناءً على الحجم الظاهر لمكونات الوعsingle وعاء';
Map<String, Object?> _payload({String? uncertainty}) => {
  'schema_version': 1,
  'response_locale': 'ar',
  'request_id': 'synthetic-v103-regression',
  'candidates': [
    {
      'name': 'وعاء السلمون والأفوكادو',
      'confidence': .96,
      'evidence': 'وعاء سمك وأفوكادو',
      'amount': 450,
      'unit': 'g',
      'uncertainty': uncertainty,
      'warnings': [],
      'alternatives': [],
      'provenance': {
        'identification_provider': 'gemini',
        'model_revision': 'v103-captured-fixture',
        'nutrition_resolution': 'requires_verified_food_match',
      },
    },
  ],
};
Matcher get _languageMismatch => throwsA(
  isA<MealImageAnalysisException>().having(
    (error) => error.failure,
    'failure',
    MealImageAnalysisFailure.languageMismatch,
  ),
);
void main() {
  test('v103 actual Arabic mixed-word uncertainty never reaches review', () {
    expect(
      () => parseMealImageResponse(
        jsonEncode(_payload(uncertainty: _bad)),
        languageCode: 'ar',
      ),
      _languageMismatch,
    );
  });
  test('every review-facing field rejects mixed Arabic Latin words', () {
    for (final field in [
      'name',
      'evidence',
      'uncertainty',
      'warnings',
      'alternatives',
    ]) {
      final payload = _payload();
      final row =
          (payload['candidates'] as List).single as Map<String, Object?>;
      row[field] = switch (field) {
        'warnings' => [_bad],
        'alternatives' => [
          {'name': _bad, 'confidence': .8},
        ],
        _ => _bad,
      };
      expect(
        () => parseMealImageResponse(jsonEncode(payload), languageCode: 'ar'),
        _languageMismatch,
        reason: field,
      );
    }
  });
  test(
    'legitimate units, scientific symbols, brands and links are preserved',
    () {
      for (final text in [
        'تقدير 450 g من الوعاء',
        'مرجع mg و RAE و B12 و µg',
        'منتج BIL من Nestle',
        'المصدر https://example.test/سلمون/salmon',
      ]) {
        final parsed = parseMealImageResponse(
          jsonEncode(_payload(uncertainty: text)),
          languageCode: 'ar',
        );
        expect(parsed.candidates.single.uncertainty, text);
        expect(parsed.candidates.single.amount, 450);
        expect(parsed.candidates.single.unit, 'g');
        expect(parsed.candidates.single.requiresReview, isTrue);
      }
    },
  );
  test(
    '200 mixed-word language failure does not repeat a paid Vision call',
    () async {
      var calls = 0;
      final service = MealImageAnalysisService(
        endpoint: 'https://vision-regression.invalid/functions/v1/analyze-meal',
        accessToken: () => 'synthetic-token',
        requestedLocale: 'ar',
        gatewayPost: ({required uri, required headers, required body}) async {
          calls++;
          return MealImageGatewayResponse(
            statusCode: 200,
            body: jsonEncode(_payload(uncertainty: _bad)),
          );
        },
      );
      await expectLater(
        service.analyze(
          XFile('assets/images/professional/recipes/salmon_avocado_bowl.jpg'),
        ),
        _languageMismatch,
      );
      expect(calls, 1);
    },
  );
}
