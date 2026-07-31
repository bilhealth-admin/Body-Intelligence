enum RecoveryState { current, gentleReturn, rebuilding }

class RecoveryReport {
  const RecoveryReport({
    required this.state,
    required this.daysAway,
    required this.title,
    required this.actions,
  });

  final RecoveryState state;
  final int daysAway;
  final String title;
  final List<String> actions;
}

class RecoveryEngine {
  const RecoveryEngine._();

  static RecoveryReport evaluate({
    required DateTime now,
    DateTime? lastTrackedAt,
  }) {
    if (lastTrackedAt == null) {
      return const RecoveryReport(
        state: RecoveryState.gentleReturn,
        daysAway: 0,
        title: 'Start today fresh',
        actions: ['Log weight', 'Log first meal'],
      );
    }
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(
      lastTrackedAt.year,
      lastTrackedAt.month,
      lastTrackedAt.day,
    );
    final days = today.difference(last).inDays.clamp(0, 36500);
    if (days < 4) {
      return RecoveryReport(
        state: RecoveryState.current,
        daysAway: days,
        title: 'Your recent record is ready',
        actions: const [],
      );
    }
    return RecoveryReport(
      state: days >= 14 ? RecoveryState.rebuilding : RecoveryState.gentleReturn,
      daysAway: days,
      title: 'Welcome back — no need to fill missing days',
      actions: const ['Start today fresh', 'Log weight', 'Log first meal'],
    );
  }
}
