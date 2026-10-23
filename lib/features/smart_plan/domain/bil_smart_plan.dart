import 'dart:convert';
part 'bil_smart_plan_setup.dart';
part 'bil_smart_plan_change.dart';
part 'bil_smart_plan_adaptation.dart';
part 'bil_smart_plan_recovery.dart';

enum BilPlanHorizon { week, month, threeMonths, sixMonths }

enum BilPlanFocus { training, nutrition, combined }

enum BilPlanStatus { draft, active, paused, completed }

enum BilPlanMealSlot { breakfast, lunch, dinner }

enum BilPlanChangeReason {
  status,
  completion,
  correction,
  schedule,
  travel,
  fatigue,
  equipment,
  mealSwap,
}

/// Dates are civil dates: never derive a diary day from UTC timestamp rounding.
abstract final class BilPlanDate {
  static DateTime atMidnight(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static String iso(DateTime value) {
    final date = atMidnight(value);
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('smart_plan_invalid_day');
    }
    final date = DateTime.tryParse(value);
    if (date == null || iso(date) != value) {
      throw const FormatException('smart_plan_invalid_day');
    }
    return atMidnight(date);
  }

  static DateTime afterMonths(DateTime start, int months) {
    final monthZero = start.month - 1 + months;
    final year = start.year + monthZero ~/ 12;
    final month = monthZero % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(year, month, start.day > lastDay ? lastDay : start.day);
  }

  static int durationDays(BilPlanHorizon horizon, DateTime start) {
    final anchor = atMidnight(start);
    final end = switch (horizon) {
      BilPlanHorizon.week => anchor.add(const Duration(days: 7)),
      BilPlanHorizon.month => afterMonths(anchor, 1),
      BilPlanHorizon.threeMonths => afterMonths(anchor, 3),
      BilPlanHorizon.sixMonths => afterMonths(anchor, 6),
    };
    return end.difference(anchor).inDays;
  }
}

int _planInt(Object? value) {
  if (value is! int || value < 0 || value > 2147483647) {
    throw const FormatException('smart_plan_invalid_integer');
  }
  return value;
}

T _readPlanEnum<T extends Enum>(Iterable<T> candidates, Object? raw) {
  for (final candidate in candidates) {
    if (candidate.name == raw) return candidate;
  }
  throw const FormatException('smart_plan_invalid_enum');
}

String _safePlanText(Object? raw, {int max = 120}) {
  if (raw is! String || raw.trim().isEmpty || raw.length > max) {
    throw const FormatException('smart_plan_invalid_text');
  }
  return raw.trim();
}

String _safePlanId(Object? raw) {
  final value = _safePlanText(raw, max: 128);
  if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]*$').hasMatch(value)) {
    throw const FormatException('smart_plan_invalid_catalog_id');
  }
  return value;
}

final class BilPlanMeal {
  const BilPlanMeal({required this.slot, required this.recipeId});

  final BilPlanMealSlot slot;
  final String recipeId;

  Map<String, Object?> toJson() => {'slot': slot.name, 'recipeId': recipeId};

  factory BilPlanMeal.fromJson(Map<String, dynamic> json) {
    if (json.keys.any((key) => !const {'slot', 'recipeId'}.contains(key))) {
      throw const FormatException('smart_plan_invalid_meal_fields');
    }
    return BilPlanMeal(
      slot: _readPlanEnum(BilPlanMealSlot.values, json['slot']),
      recipeId: _safePlanId(json['recipeId']),
    );
  }
}

final class BilPlanWorkout {
  BilPlanWorkout({
    required this.templateId,
    required Iterable<String> exerciseIds,
    required this.minutes,
    this.completed = false,
    this.effort,
  }) : exerciseIds = List.unmodifiable(exerciseIds) {
    _safePlanId(templateId);
    if (this.exerciseIds.isEmpty ||
        this.exerciseIds.length > 12 ||
        this.exerciseIds.toSet().length != this.exerciseIds.length) {
      throw const FormatException('smart_plan_invalid_exercises');
    }
    for (final id in this.exerciseIds) {
      _safePlanId(id);
    }
    if (!completed && effort != null) {
      throw const FormatException('smart_plan_effort_without_completion');
    }
    if (minutes < 5 ||
        minutes > 120 ||
        (effort != null && (effort! < 1 || effort! > 10))) {
      throw const FormatException('smart_plan_invalid_workout_load');
    }
  }

  final String templateId;
  final List<String> exerciseIds;
  final int minutes;
  final bool completed;
  final int? effort;

  BilPlanWorkout withCompletion({required bool completed, int? effort}) =>
      BilPlanWorkout(
        templateId: templateId,
        exerciseIds: exerciseIds,
        minutes: minutes,
        completed: completed,
        effort: completed ? effort : null,
      );

  Map<String, Object?> toJson() => {
    'templateId': templateId,
    'exerciseIds': exerciseIds,
    'minutes': minutes,
    'completed': completed,
    'effort': effort,
  };

  factory BilPlanWorkout.fromJson(Map<String, dynamic> json) {
    if (json.keys.any(
      (key) => !const {
        'templateId',
        'exerciseIds',
        'minutes',
        'completed',
        'effort',
      }.contains(key),
    )) {
      throw const FormatException('smart_plan_invalid_workout_fields');
    }
    final ids = json['exerciseIds'];
    if (json['completed'] is! bool) {
      throw const FormatException('smart_plan_invalid_completion');
    }
    if (ids is! List || ids.any((value) => value is! String)) {
      throw const FormatException('smart_plan_invalid_exercises');
    }
    return BilPlanWorkout(
      templateId: _safePlanId(json['templateId']),
      exerciseIds: ids.cast<String>(),
      minutes: _planInt(json['minutes']),
      completed: json['completed'] == true,
      effort: json['effort'] == null ? null : _planInt(json['effort']),
    );
  }
}

/// Meal proposals never imply food was eaten. The diary remains authoritative.
final class BilPlanDay {
  BilPlanDay({
    required this.date,
    required this.phase,
    this.workout,
    Iterable<BilPlanMeal> meals = const [],
  }) : meals = List.unmodifiable(meals) {
    BilPlanDate.parse(date);
    _safePlanText(phase);
    for (final meal in this.meals) {
      _safePlanId(meal.recipeId);
    }
    if (this.meals.length > 3 ||
        this.meals.map((meal) => meal.slot).toSet().length !=
            this.meals.length) {
      throw const FormatException('smart_plan_invalid_meals');
    }
  }

  final String date;
  final String phase;
  final BilPlanWorkout? workout;
  final List<BilPlanMeal> meals;

  BilPlanDay withWorkout(BilPlanWorkout next) =>
      BilPlanDay(date: date, phase: phase, workout: next, meals: meals);

  Map<String, Object?> toJson() => {
    'date': date,
    'phase': phase,
    'workout': workout?.toJson(),
    'meals': meals.map((meal) => meal.toJson()).toList(growable: false),
  };

  factory BilPlanDay.fromJson(Map<String, dynamic> json) {
    if (json.keys.any(
      (key) => !const {'date', 'phase', 'workout', 'meals'}.contains(key),
    )) {
      throw const FormatException('smart_plan_invalid_day_fields');
    }
    final mealRows = json['meals'];
    if (mealRows is! List) {
      throw const FormatException('smart_plan_invalid_meals');
    }
    final rawWorkout = json['workout'];
    if (rawWorkout != null && rawWorkout is! Map) {
      throw const FormatException('smart_plan_invalid_workout');
    }
    return BilPlanDay(
      date: _safePlanText(json['date'], max: 10),
      phase: _safePlanText(json['phase']),
      workout: rawWorkout == null
          ? null
          : BilPlanWorkout.fromJson(Map<String, dynamic>.from(rawWorkout)),
      meals: mealRows.map(
        (row) => BilPlanMeal.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
    );
  }
}

/// A versioned, owner-bound, reviewable schedule. Not a chat transcript.
final class BilSmartPlan {
  BilSmartPlan({
    required this.id,
    required this.ownerId,
    required this.horizon,
    required this.focus,
    required this.startDate,
    required this.status,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required Iterable<BilPlanDay> days,
    Iterable<BilPlanChange> changes = const [],
    this.setup,
  }) : days = List.unmodifiable(days),
       changes = List.unmodifiable(changes) {
    _safePlanId(id);
    _safePlanText(ownerId);
    if (revision < 1) {
      throw const FormatException('smart_plan_invalid_revision');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('smart_plan_invalid_timestamps');
    }
    final start = BilPlanDate.parse(startDate);
    if (this.changes.length > 32) {
      throw const FormatException('smart_plan_invalid_history');
    }
    var expectedChangeRevision = revision;
    var latestChangeAt = updatedAt;
    for (final change in this.changes) {
      if (change.revision != expectedChangeRevision ||
          change.at != latestChangeAt ||
          change.previousUpdatedAt.isBefore(createdAt) ||
          change.beforeDays.any(
            (day) => !this.days.any((current) => current.date == day.date),
          )) {
        throw const FormatException('smart_plan_invalid_history');
      }
      expectedChangeRevision--;
      latestChangeAt = change.previousUpdatedAt;
    }
    // A history entry is executable comparison data, not unvalidated metadata.
    // Validate each reconstructed version against the same focus/status rules.
    final historicalDays = {for (final day in this.days) day.date: day};
    for (final change in this.changes) {
      for (final before in change.beforeDays) {
        historicalDays[before.date] = before;
      }
      for (final day in historicalDays.values) {
        if ((focus == BilPlanFocus.training && day.meals.isNotEmpty) ||
            (focus == BilPlanFocus.nutrition && day.workout != null) ||
            (focus != BilPlanFocus.training && day.meals.length != 3) ||
            (change.previousStatus == BilPlanStatus.draft &&
                day.workout?.completed == true)) {
          throw const FormatException('smart_plan_invalid_history');
        }
      }
    }
    if (this.days.length != BilPlanDate.durationDays(horizon, start)) {
      throw const FormatException('smart_plan_invalid_day_count');
    }
    for (var i = 0; i < this.days.length; i++) {
      if (focus != BilPlanFocus.training && this.days[i].meals.length != 3) {
        throw const FormatException('smart_plan_incomplete_meals');
      }
      if (status == BilPlanStatus.draft &&
          this.days[i].workout?.completed == true) {
        throw const FormatException('smart_plan_draft_completed_workout');
      }
      if (this.days[i].date != BilPlanDate.iso(start.add(Duration(days: i)))) {
        throw const FormatException('smart_plan_noncontiguous_days');
      }
      if (focus == BilPlanFocus.training && this.days[i].meals.isNotEmpty) {
        throw const FormatException('smart_plan_unrequested_meals');
      }
      if (focus == BilPlanFocus.nutrition && this.days[i].workout != null) {
        throw const FormatException('smart_plan_unrequested_workouts');
      }
    }
  }

  static const int schema = 1;
  final String id;
  final String ownerId;
  final BilPlanHorizon horizon;
  final BilPlanFocus focus;
  final String startDate;
  final BilPlanStatus status;
  final int revision;
  final DateTime createdAt, updatedAt;
  final List<BilPlanDay> days;
  final List<BilPlanChange> changes;
  final BilPlanSetup? setup;

  BilPlanDay? onDate(DateTime date) {
    final iso = BilPlanDate.iso(date);
    for (final day in days) {
      if (day.date == iso) return day;
    }
    return null;
  }

  BilSmartPlan withStatus(BilPlanStatus value, DateTime now) {
    final allowed = switch (status) {
      BilPlanStatus.draft => {BilPlanStatus.active},
      BilPlanStatus.active => {BilPlanStatus.paused, BilPlanStatus.completed},
      BilPlanStatus.paused => {BilPlanStatus.active, BilPlanStatus.completed},
      BilPlanStatus.completed => <BilPlanStatus>{},
    };
    if (!allowed.contains(value)) {
      throw StateError('smart_plan_invalid_transition');
    }
    return _updated(status: value, days: days, now: now);
  }

  /// Explicit confirmation only; this method must never run on mere page view.
  BilSmartPlan deferWorkout({required DateTime date, required DateTime now}) {
    final index = days.indexWhere((day) => day.date == BilPlanDate.iso(date));
    if (status != BilPlanStatus.active ||
        index < 0 ||
        days[index].workout == null ||
        days[index].workout!.completed ||
        BilPlanDate.atMidnight(date).isBefore(BilPlanDate.atMidnight(now))) {
      throw StateError('smart_plan_cannot_defer');
    }
    var target = -1;
    for (var i = index + 1; i < days.length && i <= index + 7; i++) {
      if (days[i].workout == null) {
        target = i;
        break;
      }
    }
    if (target < 0) throw StateError('smart_plan_no_recovery_day');
    final next = List<BilPlanDay>.of(days);
    final original = days[index];
    final destination = days[target];
    next[index] = BilPlanDay(
      date: original.date,
      phase: original.phase,
      meals: original.meals,
    );
    next[target] = BilPlanDay(
      date: destination.date,
      phase: destination.phase,
      meals: destination.meals,
      workout: original.workout,
    );
    return _updated(
      status: status,
      days: next,
      now: now,
      reason: BilPlanChangeReason.schedule,
    );
  }

  BilSmartPlan recordWorkout({
    required DateTime date,
    required DateTime now,
    required bool completed,
    int? effort,
  }) {
    if (status != BilPlanStatus.active) {
      throw StateError('smart_plan_not_active');
    }
    if (BilPlanDate.atMidnight(date).isAfter(BilPlanDate.atMidnight(now))) {
      throw StateError('smart_plan_cannot_complete_future');
    }
    final dayIndex = days.indexWhere(
      (day) => day.date == BilPlanDate.iso(date),
    );
    if (dayIndex < 0 || days[dayIndex].workout == null) {
      throw StateError('smart_plan_workout_not_scheduled');
    }
    final updatedDays = List<BilPlanDay>.of(days);
    updatedDays[dayIndex] = days[dayIndex].withWorkout(
      days[dayIndex].workout!.withCompletion(
        completed: completed,
        effort: effort,
      ),
    );
    return _updated(
      status: status,
      days: updatedDays,
      now: now,
      reason: completed
          ? BilPlanChangeReason.completion
          : BilPlanChangeReason.correction,
    );
  }

  /// A preview is immutable. Only the confirmed native flow may persist it.
  BilSmartPlan rescheduleWorkout({
    required DateTime date,
    required DateTime target,
    required DateTime now,
    BilPlanChangeReason reason = BilPlanChangeReason.schedule,
  }) {
    final source = days.indexWhere((day) => day.date == BilPlanDate.iso(date));
    final destination = days.indexWhere(
      (day) => day.date == BilPlanDate.iso(target),
    );
    if (status != BilPlanStatus.active ||
        source < 0 ||
        destination < 0 ||
        source == destination ||
        days[source].workout == null ||
        days[source].workout!.completed ||
        days[destination].workout != null ||
        BilPlanDate.atMidnight(target).isBefore(BilPlanDate.atMidnight(now)) ||
        !const {
          BilPlanChangeReason.schedule,
          BilPlanChangeReason.travel,
          BilPlanChangeReason.fatigue,
          BilPlanChangeReason.equipment,
        }.contains(reason)) {
      throw StateError('smart_plan_cannot_reschedule');
    }
    final next = List<BilPlanDay>.of(days);
    next[source] = BilPlanDay(
      date: days[source].date,
      phase: days[source].phase,
      meals: days[source].meals,
    );
    next[destination] = days[destination].withWorkout(days[source].workout!);
    if (!_homeRecoverySequenceIsSafe(this, next)) {
      throw StateError('home_strength_recovery_days_required');
    }
    return _updated(status: status, days: next, now: now, reason: reason);
  }

  BilSmartPlan replaceMeal({
    required DateTime date,
    required BilPlanMealSlot slot,
    required String recipeId,
    required DateTime now,
  }) {
    _safePlanId(recipeId);
    final index = days.indexWhere((day) => day.date == BilPlanDate.iso(date));
    if (status != BilPlanStatus.active ||
        index < 0 ||
        BilPlanDate.atMidnight(date).isBefore(BilPlanDate.atMidnight(now)) ||
        !days[index].meals.any(
          (meal) => meal.slot == slot && meal.recipeId != recipeId,
        )) {
      throw StateError('smart_plan_cannot_replace_meal');
    }
    final next = List<BilPlanDay>.of(days);
    final day = days[index];
    next[index] = BilPlanDay(
      date: day.date,
      phase: day.phase,
      workout: day.workout,
      meals: day.meals.map(
        (meal) => meal.slot == slot
            ? BilPlanMeal(slot: slot, recipeId: recipeId)
            : meal,
      ),
    );
    return _updated(
      status: status,
      days: next.toList(growable: false),
      now: now,
      reason: BilPlanChangeReason.mealSwap,
    );
  }

  /// Comparison only, never a write or an automatic rollback of diary data.
  BilSmartPlan? previousVersion() {
    if (changes.isEmpty) return null;
    final change = changes.first;
    return BilSmartPlan(
      id: id,
      ownerId: ownerId,
      horizon: horizon,
      focus: focus,
      startDate: startDate,
      status: change.previousStatus,
      revision: revision - 1,
      createdAt: createdAt,
      updatedAt: change.previousUpdatedAt,
      days: days.map(
        (day) =>
            change.beforeDays
                .where((before) => before.date == day.date)
                .firstOrNull ??
            day,
      ),
      changes: changes.skip(1),
      setup: setup,
    );
  }

  BilSmartPlan _updated({
    required BilPlanStatus status,
    required List<BilPlanDay> days,
    required DateTime now,
    BilPlanChangeReason reason = BilPlanChangeReason.status,
  }) => BilSmartPlan(
    id: id,
    ownerId: ownerId,
    horizon: horizon,
    focus: focus,
    startDate: startDate,
    status: status,
    revision: revision + 1,
    createdAt: createdAt,
    updatedAt: now.toUtc(),
    days: days,
    setup: setup,
    changes: [
      BilPlanChange(
        revision: revision + 1,
        at: now.toUtc(),
        previousUpdatedAt: updatedAt,
        reason: reason,
        previousStatus: this.status,
        beforeDays: this.days.where(
          (before) =>
              jsonEncode(before.toJson()) !=
              jsonEncode(
                days.firstWhere((day) => day.date == before.date).toJson(),
              ),
        ),
      ),
      ...changes.take(31),
    ],
  );

  double get workoutCompletion {
    var expected = 0, completed = 0;
    for (final day in days) {
      if (day.workout != null) {
        expected++;
        if (day.workout!.completed) completed++;
      }
    }
    return expected == 0 ? 0 : completed / expected;
  }

  Map<String, Object?> toJson() => {
    'schema': schema,
    if (setup != null) 'setup': setup!.toJson(),
    'id': id,
    'ownerId': ownerId,
    'horizon': horizon.name,
    'focus': focus.name,
    'startDate': startDate,
    'status': status.name,
    'revision': revision,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'days': days.map((day) => day.toJson()).toList(growable: false),
    if (changes.isNotEmpty)
      'changes': changes
          .map((change) => change.toJson())
          .toList(growable: false),
  };

  String encode() {
    final raw = jsonEncode(toJson());
    if (utf8.encode(raw).length > 250000) {
      throw const FormatException('smart_plan_too_large');
    }
    return raw;
  }

  factory BilSmartPlan.decode(String raw) {
    if (utf8.encode(raw).length > 250000) {
      throw const FormatException('smart_plan_too_large');
    }
    final value = jsonDecode(raw);
    if (value is! Map || value['schema'] is! int || value['schema'] != schema) {
      throw const FormatException('smart_plan_unknown_schema');
    }
    final data = Map<String, dynamic>.from(value);
    if (data.keys.any(
          (key) => !const {
            'schema',
            'id',
            'ownerId',
            'horizon',
            'focus',
            'startDate',
            'status',
            'revision',
            'createdAt',
            'updatedAt',
            'days',
            'changes',
            'setup',
          }.contains(key),
        ) ||
        (data.containsKey('setup') && data['setup'] is! Map) ||
        (data.containsKey('changes') && data['changes'] is! List)) {
      throw const FormatException('smart_plan_invalid_fields');
    }
    final rows = data['days'];
    if (rows is! List || rows.length > 190) {
      throw const FormatException('smart_plan_invalid_days');
    }
    return BilSmartPlan(
      id: _safePlanId(data['id']),
      ownerId: _safePlanText(data['ownerId']),
      horizon: _readPlanEnum(BilPlanHorizon.values, data['horizon']),
      focus: _readPlanEnum(BilPlanFocus.values, data['focus']),
      startDate: _safePlanText(data['startDate'], max: 10),
      status: _readPlanEnum(BilPlanStatus.values, data['status']),
      revision: _planInt(data['revision']),
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
      days: rows.map(
        (row) => BilPlanDay.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
      changes: data['changes'] == null
          ? const []
          : (data['changes'] as List).map(
              (row) =>
                  BilPlanChange.fromJson(Map<String, dynamic>.from(row as Map)),
            ),
      setup: data['setup'] == null
          ? null
          : BilPlanSetup.fromJson(
              Map<String, dynamic>.from(data['setup'] as Map),
            ),
    );
  }
}
