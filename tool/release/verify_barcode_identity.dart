import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/domain/barcode_identity.dart';

void main() {
  const cases = <String, BarcodeValidationIssue?>{
    '4006381333931': null,
    '4006381333932': BarcodeValidationIssue.invalidCheckDigit,
    '12345': BarcodeValidationIssue.unsupportedLength,
    'not-a-barcode': BarcodeValidationIssue.empty,
  };

  for (final entry in cases.entries) {
    final identity = BarcodeIdentity.parse(entry.key);
    if (identity.issue != entry.value) {
      throw StateError(
        '${entry.key}: expected ${entry.value}, got ${identity.issue}',
      );
    }
  }

  final normalized = BarcodeIdentity.parse('4006 3813-3393 1');
  if (!normalized.isValid || normalized.digits != '4006381333931') {
    throw StateError('Formatted EAN-13 was not canonicalized safely.');
  }

  stdout.writeln('BARCODE_IDENTITY=PASS');
  stdout.writeln('VALID_EAN13=PASS');
  stdout.writeln('INVALID_CHECK_DIGIT_REJECTED=PASS');
  stdout.writeln('UNSUPPORTED_LENGTH_REJECTED=PASS');
  stdout.writeln('NON_DIGIT_INPUT_REJECTED=PASS');
  stdout.writeln('FORMATTED_INPUT_CANONICALIZED=PASS');
}
