/// Product-wide adult eligibility boundary for the Google Play release.
///
/// New users are evaluated from their date of birth. Legacy profiles only
/// retain the previously calculated age, so startup uses [isEligibleAge] as a
/// fail-closed compatibility check until the user confirms their birth date.
abstract final class BilAdultEligibility {
  static const int minimumAge = 18;

  static int ageOn(DateTime birthDate, {DateTime? on}) {
    final date = DateTime(birthDate.year, birthDate.month, birthDate.day);
    final referenceValue = on ?? DateTime.now();
    final reference = DateTime(
      referenceValue.year,
      referenceValue.month,
      referenceValue.day,
    );
    var age = reference.year - date.year;
    final birthdayPassed =
        reference.month > date.month ||
        (reference.month == date.month && reference.day >= date.day);
    if (!birthdayPassed) age--;
    return age;
  }

  static bool isEligibleBirthDate(DateTime birthDate, {DateTime? on}) =>
      ageOn(birthDate, on: on) >= minimumAge;

  static bool isEligibleAge(int age) => age >= minimumAge;

  static DateTime latestEligibleBirthDate({DateTime? on}) {
    final reference = on ?? DateTime.now();
    return DateTime(
      reference.year - minimumAge,
      reference.month,
      reference.day,
    );
  }
}
