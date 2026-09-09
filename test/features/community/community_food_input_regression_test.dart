import 'package:body_intelligence_log/features/community/domain/community_food_input.dart';
import 'package:flutter_test/flutter_test.dart';

Map<CommunityFoodField, String> validInput() => {
  CommunityFoodField.name: '  Test food  ',
  CommunityFoodField.serving: '100',
  CommunityFoodField.calories: '165',
  CommunityFoodField.protein: '10',
  CommunityFoodField.carbohydrate: '20',
  CommunityFoodField.fat: '5',
};

void main() {
  group('community food decimal parsing', () {
    for (final (input, expected) in <(String, double)>[
      ('0', 0),
      ('1.25', 1.25),
      (' 1,25 ', 1.25),
      ('١٢٫٥', 12.5),
      ('۱۲٫۵', 12.5),
      ('１２.５', 12.5),
      ('१२.५', 12.5),
      ('১২.৫', 12.5),
      ('๑๒.๕', 12.5),
      ('.5', .5),
      ('12.', 12),
    ]) {
      test('accepts decimal $input', () {
        expect(parseCommunityFoodNumber(input), expected);
      });
    }
    for (final input in [
      '',
      ' ',
      '-1',
      'NaN',
      'Infinity',
      '1e3',
      '1,2,3',
      '1.2.3',
      '١٬٠٠٠',
      '10 g',
      '1 000',
    ]) {
      test('rejects invalid or ambiguous $input', () {
        expect(parseCommunityFoodNumber(input), isNull);
      });
    }
    test('rejects decimal overflow', () {
      expect(parseCommunityFoodNumber(List.filled(400, '9').join()), isNull);
    });
  });
  group('per-serving validation', () {
    test('valid values preserve zero and trim the name', () {
      final values = validInput()..[CommunityFoodField.protein] = '0';
      final result = validateCommunityFoodInput(values);
      expect(result.isValid, isTrue);
      expect(result.draft!.name, 'Test food');
      expect(result.draft!.protein, 0);
      expect(result.draft!.carbohydrate, 20);
    });
    test('missing values are not fabricated as zero', () {
      final values = validInput()..remove(CommunityFoodField.calories);
      final result = validateCommunityFoodInput(values);
      expect(result.draft, isNull);
      expect(
        result.issues[CommunityFoodField.calories],
        CommunityFoodInputIssue.missingValue,
      );
    });
    test('the tester screenshot is rejected before a draft is created', () {
      final result = validateCommunityFoodInput({
        CommunityFoodField.name: 'b',
        CommunityFoodField.serving: '5',
        CommunityFoodField.calories: '',
        CommunityFoodField.protein: '255',
        CommunityFoodField.carbohydrate: '',
        CommunityFoodField.fat: '588',
      });
      expect(result.isValid, isFalse);
      expect(
        result.issues.keys,
        containsAll([
          CommunityFoodField.name,
          CommunityFoodField.calories,
          CommunityFoodField.carbohydrate,
          CommunityFoodField.protein,
          CommunityFoodField.fat,
        ]),
      );
    });
    test('zero serving cannot be submitted', () {
      final result = validateCommunityFoodInput(
        validInput()..[CommunityFoodField.serving] = '0',
      );
      expect(
        result.issues[CommunityFoodField.serving],
        CommunityFoodInputIssue.positiveServing,
      );
    });
    test('macro total is bounded by serving mass', () {
      final result = validateCommunityFoodInput(
        validInput()
          ..[CommunityFoodField.protein] = '50'
          ..[CommunityFoodField.carbohydrate] = '50'
          ..[CommunityFoodField.fat] = '50',
      );
      expect(
        result.issues[CommunityFoodField.fat],
        CommunityFoodInputIssue.macroTotalExceedsServing,
      );
    });
    test('small rounded-label differences remain allowed', () {
      final result = validateCommunityFoodInput(
        validInput()
          ..[CommunityFoodField.protein] = '33.5'
          ..[CommunityFoodField.carbohydrate] = '33.5'
          ..[CommunityFoodField.fat] = '33.5',
      );
      expect(result.isValid, isTrue);
    });
    test('server calorie range is checked without rewriting the value', () {
      final result = validateCommunityFoodInput(
        validInput()..[CommunityFoodField.calories] = '10001',
      );
      expect(
        result.issues[CommunityFoodField.calories],
        CommunityFoodInputIssue.tooLarge,
      );
    });
    test('overlong name is rejected', () {
      final result = validateCommunityFoodInput(
        validInput()..[CommunityFoodField.name] = List.filled(181, 'x').join(),
      );
      expect(
        result.issues[CommunityFoodField.name],
        CommunityFoodInputIssue.nameLength,
      );
    });
  });
}
