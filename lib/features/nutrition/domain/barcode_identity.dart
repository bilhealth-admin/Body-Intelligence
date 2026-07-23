import '../services/food_search_normalizer.dart';

enum BarcodeSymbology { ean8, upcA, ean13, gtin14, unsupported }

enum BarcodeValidationIssue { empty, unsupportedLength, invalidCheckDigit }

class BarcodeIdentity {
  final String raw;
  final String digits;
  final BarcodeSymbology symbology;
  final BarcodeValidationIssue? issue;

  const BarcodeIdentity._({
    required this.raw,
    required this.digits,
    required this.symbology,
    required this.issue,
  });

  factory BarcodeIdentity.parse(String input) {
    final digits = FoodSearchNormalizer.normalizeBarcode(input);
    if (digits.isEmpty) {
      return BarcodeIdentity._(
        raw: input,
        digits: digits,
        symbology: BarcodeSymbology.unsupported,
        issue: BarcodeValidationIssue.empty,
      );
    }

    final symbology = switch (digits.length) {
      8 => BarcodeSymbology.ean8,
      12 => BarcodeSymbology.upcA,
      13 => BarcodeSymbology.ean13,
      14 => BarcodeSymbology.gtin14,
      _ => BarcodeSymbology.unsupported,
    };
    if (symbology == BarcodeSymbology.unsupported) {
      return BarcodeIdentity._(
        raw: input,
        digits: digits,
        symbology: symbology,
        issue: BarcodeValidationIssue.unsupportedLength,
      );
    }

    return BarcodeIdentity._(
      raw: input,
      digits: digits,
      symbology: symbology,
      issue: _hasValidCheckDigit(digits)
          ? null
          : BarcodeValidationIssue.invalidCheckDigit,
    );
  }

  bool get isValid => issue == null;

  static bool _hasValidCheckDigit(String digits) {
    final expected = int.parse(digits[digits.length - 1]);
    var sum = 0;
    var useTripleWeight = true;
    for (var index = digits.length - 2; index >= 0; index--) {
      final digit = int.parse(digits[index]);
      sum += digit * (useTripleWeight ? 3 : 1);
      useTripleWeight = !useTripleWeight;
    }
    final calculated = (10 - (sum % 10)) % 10;
    return calculated == expected;
  }
}
