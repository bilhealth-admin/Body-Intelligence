import 'package:body_intelligence_log/features/auth/auth_input_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('international phone normalization', () {
    test('removes Egyptian trunk zeroes', () {
      expect(
        AuthInputValidation.normalizeNationalPhone('01122265552', '20'),
        '+201122265552',
      );
      expect(
        AuthInputValidation.normalizeNationalPhone('0001122265552', '20'),
        '+201122265552',
      );
    });

    test('normalizes visible national input while it is edited', () {
      expect(
        AuthInputValidation.normalizeVisibleNationalPhone('01122265552', '20'),
        '1122265552',
      );
      expect(
        AuthInputValidation.normalizeVisibleNationalPhone(
          '0001122265552',
          '20',
        ),
        '1122265552',
      );
    });

    test('reduces a pasted selected-country number to its national part', () {
      expect(
        AuthInputValidation.normalizeVisibleNationalPhone(
          '+201122265552',
          '20',
        ),
        '1122265552',
      );
      expect(
        AuthInputValidation.normalizeVisibleNationalPhone(
          '00201122265552',
          '20',
        ),
        '1122265552',
      );
    });

    test(
      'does not combine an explicit foreign number with selected prefix',
      () {
        expect(
          AuthInputValidation.normalizeVisibleNationalPhone(
            '+971501234567',
            '20',
          ),
          '+971501234567',
        );
        expect(
          AuthInputValidation.isValidNationalPhone('+971501234567', '20'),
          isFalse,
        );
      },
    );

    test('preserves an explicitly international number', () {
      expect(
        AuthInputValidation.normalizeNationalPhone('00201122265552', '20'),
        '+201122265552',
      );
      expect(
        AuthInputValidation.normalizeNationalPhone('+971501234567', '20'),
        '+971501234567',
      );
    });

    test('validates a national number against the selected dialing code', () {
      expect(
        AuthInputValidation.isValidNationalPhone('01122265552', '20'),
        isTrue,
      );
      expect(AuthInputValidation.isValidNationalPhone('12', '20'), isFalse);
    });
  });
}
