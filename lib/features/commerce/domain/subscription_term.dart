/// Supported commercial subscription durations for promotion eligibility.
enum SubscriptionTerm {
  oneMonth(1),
  threeMonths(3),
  sixMonths(6),
  oneYear(12);

  const SubscriptionTerm(this.months);

  final int months;
}
