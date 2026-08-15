enum DailyReminderKind {
  weight,
  meals,
  water,
  sleep,
  fasting,
  weeklyReview,
  returnAfter24Hours,
}

class DailyReminder {
  const DailyReminder({
    required this.kind,
    required this.hour,
    required this.minute,
    this.enabled = false,
  });
  final DailyReminderKind kind;
  final int hour;
  final int minute;
  final bool enabled;
  int get notificationId => 7100 + kind.index;
}
