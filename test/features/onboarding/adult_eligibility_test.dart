import 'package:body_intelligence_log/features/onboarding/domain/adult_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reference = DateTime(2026, 8, 24);

  test('18th birthday is the exact production eligibility boundary', () {
    expect(
      BilAdultEligibility.isEligibleBirthDate(
        DateTime(2008, 8, 24),
        on: reference,
      ),
      isTrue,
    );
    expect(
      BilAdultEligibility.isEligibleBirthDate(
        DateTime(2008, 8, 25),
        on: reference,
      ),
      isFalse,
    );
    expect(BilAdultEligibility.isEligibleAge(17), isFalse);
    expect(BilAdultEligibility.isEligibleAge(18), isTrue);
  });

  test('future and child birth dates fail closed', () {
    expect(
      BilAdultEligibility.isEligibleBirthDate(
        DateTime(2027, 1, 1),
        on: reference,
      ),
      isFalse,
    );
    expect(
      BilAdultEligibility.latestEligibleBirthDate(on: reference),
      DateTime(2008, 8, 24),
    );
  });
}
