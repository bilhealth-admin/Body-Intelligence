import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
      return schedule.isValid ? schedule : null;
    } on Object {
      return null;
    }
  }

  bool get isValid =>
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
    if (!value.isValid) throw ArgumentError.value(value, 'value');
    final prefs = await _preferences;
    final saved = await prefs.setString(storageKey, jsonEncode(value.toJson()));
    if (!saved) throw StateError('sleep_schedule_not_saved');
  }
}
