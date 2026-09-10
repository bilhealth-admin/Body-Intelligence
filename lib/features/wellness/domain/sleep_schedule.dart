import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum SleepScheduleIssue {
  invalidClock,
  invalidGoal,
  invalidWindDown,
  emptyWindow,
  goalExceedsWindow,
}

/// User-owned sleep schedule. Clock fields are local wall-clock values so
/// recurring reminders follow timezone and DST changes instead of preserving
/// a stale UTC offset.
final class SleepSchedule {
  const SleepSchedule({
    required this.enabled,
    required this.bedHour,
    required this.bedMinute,
    required this.wakeHour,
    required this.wakeMinute,
    required this.goalMinutes,
    required this.windDownMinutes,
  });

  const SleepSchedule.defaults()
    : enabled = false,
      bedHour = 22,
      bedMinute = 30,
      wakeHour = 7,
      wakeMinute = 0,
      goalMinutes = 8 * 60,
      windDownMinutes = 30;

  final bool enabled;
  final int bedHour;
  final int bedMinute;
  final int wakeHour;
  final int wakeMinute;
  final int goalMinutes;
  final int windDownMinutes;

  /// Nominal local-wall-clock window, including schedules that cross
  /// midnight. The operating system owns timezone/DST adjustment for the
  /// recurring reminder; this value is intentionally not a UTC duration.
  int get scheduledWindowMinutes {
    final bed = bedHour * 60 + bedMinute;
    final wake = wakeHour * 60 + wakeMinute;
    return (wake - bed) % Duration.minutesPerDay;
  }

  SleepScheduleIssue? get issue {
    if (bedHour < 0 ||
        bedHour > 23 ||
        bedMinute < 0 ||
        bedMinute > 59 ||
        wakeHour < 0 ||
        wakeHour > 23 ||
        wakeMinute < 0 ||
        wakeMinute > 59) {
      return SleepScheduleIssue.invalidClock;
    }
    // BIL is an adult (18+) product. Planning goals start at the current
    // evidence-based adult floor of seven hours. This does not censor or
    // reinterpret a shorter actual sleep record.
    if (goalMinutes < 7 * 60 || goalMinutes > 12 * 60) {
      return SleepScheduleIssue.invalidGoal;
    }
    if (windDownMinutes < 0 || windDownMinutes > 120) {
      return SleepScheduleIssue.invalidWindDown;
    }
    if (scheduledWindowMinutes == 0) return SleepScheduleIssue.emptyWindow;
    if (goalMinutes > scheduledWindowMinutes) {
      return SleepScheduleIssue.goalExceedsWindow;
    }
    return null;
  }

  /// Whether the value is structurally safe to preserve in the v1 store.
  ///
  /// Earlier BIL releases allowed planning goals down to four hours and did
  /// not compare the goal with the scheduled window. Keeping that historical
  /// shape readable prevents a stricter planning rule from silently replacing
  /// an existing user schedule with defaults. Enabling still requires
  /// [isValid]; disabling must not be blocked by an older planning goal.
  bool get isStorable =>
      bedHour >= 0 &&
      bedHour <= 23 &&
      bedMinute >= 0 &&
      bedMinute <= 59 &&
      wakeHour >= 0 &&
      wakeHour <= 23 &&
      wakeMinute >= 0 &&
      wakeMinute <= 59 &&
      goalMinutes >= 4 * 60 &&
      goalMinutes <= 12 * 60 &&
      windDownMinutes >= 0 &&
      windDownMinutes <= 120;

  SleepSchedule copyWith({
    bool? enabled,
    int? bedHour,
    int? bedMinute,
    int? wakeHour,
    int? wakeMinute,
    int? goalMinutes,
    int? windDownMinutes,
  }) => SleepSchedule(
    enabled: enabled ?? this.enabled,
    bedHour: bedHour ?? this.bedHour,
    bedMinute: bedMinute ?? this.bedMinute,
    wakeHour: wakeHour ?? this.wakeHour,
    wakeMinute: wakeMinute ?? this.wakeMinute,
    goalMinutes: goalMinutes ?? this.goalMinutes,
    windDownMinutes: windDownMinutes ?? this.windDownMinutes,
  );

  Map<String, Object> toJson() => <String, Object>{
    'enabled': enabled,
    'bedHour': bedHour,
    'bedMinute': bedMinute,
    'wakeHour': wakeHour,
    'wakeMinute': wakeMinute,
    'goalMinutes': goalMinutes,
    'windDownMinutes': windDownMinutes,
  };

  static SleepSchedule? tryParse(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final schedule = SleepSchedule(
        enabled: value['enabled'] as bool,
        bedHour: value['bedHour'] as int,
        bedMinute: value['bedMinute'] as int,
        wakeHour: value['wakeHour'] as int,
        wakeMinute: value['wakeMinute'] as int,
        goalMinutes: value['goalMinutes'] as int,
        windDownMinutes: value['windDownMinutes'] as int,
      );
      return schedule.isStorable ? schedule : null;
    } on Object {
      return null;
    }
  }

  bool get isValid => issue == null;
}

class SleepScheduleStore {
  SleepScheduleStore({Future<SharedPreferences>? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance();

  static const storageKey = 'wellness_sleep_schedule_v1';
  final Future<SharedPreferences> _preferences;

  Future<SleepSchedule> load() async {
    try {
      final prefs = await _preferences;
      return SleepSchedule.tryParse(prefs.getString(storageKey)) ??
          const SleepSchedule.defaults();
    } on Object {
      return const SleepSchedule.defaults();
    }
  }

  Future<void> save(SleepSchedule value) async {
    if (!value.isStorable || (value.enabled && !value.isValid)) {
      throw ArgumentError.value(value, 'value');
    }
    final prefs = await _preferences;
    final saved = await prefs.setString(storageKey, jsonEncode(value.toJson()));
    if (!saved) throw StateError('sleep_schedule_not_saved');
  }
}
