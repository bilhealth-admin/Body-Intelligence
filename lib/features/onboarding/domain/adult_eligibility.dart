/// Product-wide adult eligibility boundary for the Google Play release.
///
/// New users are evaluated from their date of birth. Legacy profiles only
/// retain the previously calculated age, so startup uses [isEligibleAge] as a
/// fail-closed compatibility check until the user confirms their birth date.
abstract final class BilAdultEligibility {
  static const int minimumAge = 18;
  static const int maximumSupportedAge = 120;

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

  static bool isEligibleBirthDate(DateTime birthDate, {DateTime? on}) {
    final age = ageOn(birthDate, on: on);
    return age >= minimumAge && age <= maximumSupportedAge;
  }

  static bool isEligibleAge(int age) =>
      age >= minimumAge && age <= maximumSupportedAge;

  static DateTime latestEligibleBirthDate({DateTime? on}) {
    final reference = on ?? DateTime.now();
    final targetYear = reference.year - minimumAge;
    // `DateTime(year, 2, 29)` normalizes to March 1 in a non-leap target
    // year. Clamp explicitly so a Feb 29 reference never admits someone born
    // on March 1 one day before their 18th birthday.
    final lastDayOfTargetMonth = DateTime(
      targetYear,
      reference.month + 1,
      0,
    ).day;
    final targetDay = reference.day > lastDayOfTargetMonth
        ? lastDayOfTargetMonth
        : reference.day;
    return DateTime(targetYear, reference.month, targetDay);
  }
}
